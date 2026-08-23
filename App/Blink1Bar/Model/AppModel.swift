import Blink1
import Blink1Control
import Foundation
import Observation

/// The app's single source of truth: settings in, one `DeviceOutput` out.
///
/// Everything that could later become a status source — a build watcher, an agent hook — ends up
/// feeding this same funnel, so the arbitration lives here and nowhere else.
@Observable
final class AppModel {

    var preferences: Preferences {
        didSet {
            guard preferences != oldValue else { return }
            preferences.save()
            claimAmbient()
            syncMeterSettings()
            handleInputActivity(inputMonitor.activity)
            Task { await applyCurrentOutput() }
        }
    }

    /// Everything that wants the LED goes through here, including the menu's own mode.
    let arbiter = StatusArbiter()

    private(set) var connection: Blink1Coordinator.Connection?
    private(set) var attachedDevices: [Blink1.Info] = []
    private(set) var lastErrorMessage: String?
    /// Recomputed on the clock so the menu can show the color the device is fading through.
    private(set) var timeOfDayColor: Blink1.Color = TimeOfDayPalette.color()

    private let coordinator = Blink1Coordinator()
    private let powerMonitor = PowerMonitor()
    private let controlServer = ControlServer()
    private let inputMonitor = InputActivityMonitor()

    /// The continuous meters. Whichever one the winning claim names gets driven, the rest stay shut.
    let audioMeter = AudioMeter()
    let systemLoadMeter = SystemLoadMeter()
    let networkMeter = NetworkMeter()
    private var appliedOutput: DeviceOutput?
    private var appliedBrightness: Double?
    private var lastBlipHour: Int?
    private var isAsleep = false
    private var physicalResetAlertedSerialNumber: String?
    private var tasks: [Task<Void, Never>] = []

    /// The watchdog has to be re-armed well inside its own timeout, or it fires on a healthy app.
    private static let watchdogTimeout = Duration.seconds(30)
    private static let watchdogHeartbeat = Duration.seconds(10)

    /// 30 frames a second: the device needs 6ms for a stereo frame and interpolates the rest, while
    /// its fade engine only ticks every 10ms — going faster would cost USB traffic for nothing.


    init() {
        self.preferences = .load()
        claimAmbient()
        syncMeterSettings()
    }

    /// The sliders live in the preferences, the meter does the work with them.
    private func syncMeterSettings() {
        audioMeter.manualFloorDecibels = preferences.audioFloorDecibels
        audioMeter.manualExpansion = preferences.audioExpansion
        audioMeter.adjustsAutomatically = preferences.audioAutoAdjusts
    }

    /// The mode picked in the menu is a claim like any other — the one everything else outranks.
    private func claimAmbient() {
        let presentation: StatusClaim.Presentation = switch preferences.mode {
            case .off: .off
            case .color: .color(preferences.staticColor)
            case .signal: .signal(preferences.signal)
            case .timeOfDay: .color(timeOfDayColor)
            case .meter: .meter(preferences.meterKind)
        }
        arbiter.claim(.init(source: .ambient, priority: .ambient, presentation: presentation))
    }

    var isConnected: Bool { connection != nil }

    /// What the LED should show: whichever claim currently outranks the rest.
    var currentOutput: DeviceOutput {
        arbiter.winner?.presentation.output ?? .off
    }

    /// A claim from somewhere other than the menu, if one is showing — for the menu to display.
    var externalClaim: StatusClaim? {
        guard let winner = arbiter.winner, winner.source != .ambient else { return nil }
        return winner
    }

    /// Puts a status in front of the ambient mode.
    func claim(_ presentation: StatusClaim.Presentation,
               priority: StatusClaim.Priority,
               from source: StatusClaim.Source = .external,
               label: String? = nil,
               for duration: Duration? = nil) {
        arbiter.claim(.init(source: source, priority: priority, presentation: presentation,
                            label: label, duration: duration))
        Task { await applyCurrentOutput() }
    }

    func withdrawClaim(from source: StatusClaim.Source = .external) {
        arbiter.withdraw(source)
        Task { await applyCurrentOutput() }
    }

    /// Everything pushed in steps aside; the mode picked in the menu has the LED back.
    func withdrawAllClaims() {
        arbiter.withdrawAll()
        Task { await applyCurrentOutput() }
    }

    /// The meter behind a `.meter` presentation.
    func meter(for kind: LiveMeterKind) -> any LiveMeter {
        switch kind {
            case .audio: audioMeter
            case .systemLoad: systemLoadMeter
            case .network: networkMeter
        }
    }

    var effectiveBrightness: Double { preferences.effectiveBrightness() }

    // MARK: - Lifecycle

    func start() {
        guard tasks.isEmpty else { return }
        tasks.append(Task { await self.watchForDevices() })
        tasks.append(Task { await self.followTheClock() })
        tasks.append(Task { await self.feedTheWatchdog() })
        tasks.append(Task { await self.followLiveMeter() })
        tasks.append(Task { await self.expireClaims() })
        powerMonitor.start(onSleep: { [weak self] in self?.handleSleep() },
                           onWake: { [weak self] in self?.handleWake() })
        startControlServer()
        inputMonitor.start(ignoring: { [weak self] in
            guard let deviceID = self?.audioMeter.deviceID else { return [] }
            return [deviceID]
        }, onChange: { [weak self] activity in
            self?.handleInputActivity(activity)
        })
    }

    /// A live microphone is the one thing the lamp says to the room rather than to its owner, so it
    /// claims above everything else: an error taking the LED back mid-call would be a lie at the
    /// worst possible moment.
    private func handleInputActivity(_ activity: InputActivityMonitor.Activity) {
        guard preferences.signalsInputActivity, activity.isActive else {
            withdrawClaim(from: .inputActivity)
            return
        }
        claim(.color(Blink1.Color(red: 255, green: 0, blue: 0)),
              priority: .alert,
              from: .inputActivity,
              label: activity.microphone ? R.L.Input_MICROPHONE : R.L.Input_CAMERA)
    }

    /// Lets scripts and the CLI report status instead of fighting over the device.
    private func startControlServer() {
        do {
            try controlServer.start { [weak self] request in
                guard let self else { return .failure("Blink1Bar is shutting down") }
                return await MainActor.run { self.handle(request) }
            }
        } catch {
            lastErrorMessage = "\(error)"
        }
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        powerMonitor.stop()
        controlServer.stop()
        inputMonitor.stop()
    }

    /// Called on the way out: a deliberate quit is not a fault, so the watchdog must not fire.
    func prepareForTermination() async {
        stop()
        await coordinator.disarmWatchdog()
    }

    // MARK: - Login item

    var startsAtLogin: Bool { LoginItem.isEnabled }

    func setStartsAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Sleep and wake

    private func handleSleep() {
        isAsleep = true
        Task {
            // A sleeping Mac is not a crashed app; letting the watchdog fire here would be a lie.
            await coordinator.disarmWatchdog()
            guard preferences.sleepBehavior == .off else { return }
            await apply(.off, brightness: effectiveBrightness)
        }
    }

    private func handleWake() {
        isAsleep = false
        Task {
            // The device may have been re-enumerated while the Mac slept, which makes the open
            // handle useless — start over rather than trust it.
            await coordinator.disconnect()
            connection = nil
            appliedOutput = nil
            await connectIfNeeded()
            await applyCurrentOutput()
        }
    }

    private func feedTheWatchdog() async {
        while !Task.isCancelled {
            if preferences.armsWatchdog, !isAsleep, connection != nil {
                do {
                    try await coordinator.armWatchdog(timeout: Self.watchdogTimeout)
                } catch let error as Blink1Error {
                    await invalidateConnection(error)
                    await applyCurrentOutput()
                } catch {
                    await invalidateConnection(error.localizedDescription)
                    await applyCurrentOutput()
                }
            }
            try? await Task.sleep(for: Self.watchdogHeartbeat)
        }
    }

    // MARK: - Actions

    /// Applies a brightness without storing it, so dragging the slider stays responsive.
    ///
    /// Signals are left out on purpose: their brightness lives in the bank, and rewriting 32 slots
    /// per slider step would swamp the device. They pick the new value up when the drag ends.
    func previewBrightness(_ value: Double) {
        switch preferences.mode {
            case .color, .timeOfDay: Task { await apply(currentOutput, brightness: value) }
            // Audio picks the new brightness up with its next frame, a thirtieth of a second later.
            case .off, .signal, .meter: break
        }
    }

    func commitBrightness(_ value: Double) {
        preferences.brightness = value
    }

    func reinstallBank() {
        Task {
            await coordinator.disconnect()
            connection = nil
            await connectIfNeeded()
            await applyCurrentOutput()
        }
    }

    func selectDevice(serialNumber: String?) {
        preferences.preferredSerialNumber = serialNumber
        Task {
            await coordinator.disconnect()
            connection = nil
            await connectIfNeeded()
            await applyCurrentOutput()
        }
    }

    // MARK: - Device plumbing

    private func watchForDevices() async {
        while !Task.isCancelled {
            attachedDevices = await coordinator.attachedDevices()
            if attachedDevices.isEmpty {
                physicalResetAlertedSerialNumber = nil
            }
            if connection == nil, !attachedDevices.isEmpty {
                await connectIfNeeded()
                await applyCurrentOutput()
            } else if attachedDevices.isEmpty, connection != nil {
                await coordinator.disconnect()
                connection = nil
            }
            try? await Task.sleep(for: .seconds(2))
        }
    }

    /// Keeps the clock-driven color current and fires the hourly blip.
    private func followTheClock() async {
        while !Task.isCancelled {
            let color = TimeOfDayPalette.color()
            if color != timeOfDayColor {
                timeOfDayColor = color
                if preferences.mode == .timeOfDay { claimAmbient() }
            }
            await blipIfANewHourStarted()
            await resyncIfTheDeviceDrifted()
            await applyCurrentOutput()
            try? await Task.sleep(for: .seconds(20))
        }
    }

    /// Something else may have written to the device; if so, take it back.
    private func resyncIfTheDeviceDrifted() async {
        guard !isAsleep, connection != nil, appliedOutput != nil else { return }
        do {
            guard try await coordinator.needsResync(for: currentOutput,
                                                    brightness: effectiveBrightness) else { return }
            appliedOutput = nil
        } catch let error as Blink1Error {
            await invalidateConnection(error)
        } catch {
            await invalidateConnection(error.localizedDescription)
        }
    }

    /// A failed read is a failed connection check, not evidence that the cached output is correct.
    private func invalidateConnection(_ error: Blink1Error) async {
        await invalidateConnection(error.description)
    }

    private func invalidateConnection(_ message: String) async {
        await coordinator.disconnect()
        connection = nil
        appliedOutput = nil
        lastErrorMessage = message
    }

    /// Hands the LED back when a claim lapses.
    ///
    /// Without this the device would keep showing an expired status until something else happened to
    /// re-apply — which in a quiet mode like the clock could be twenty seconds later.
    private func expireClaims() async {
        while !Task.isCancelled {
            if arbiter.dropExpiredClaims() {
                await applyCurrentOutput()
            }
            // Only worth checking often while something actually has an expiry date.
            try? await Task.sleep(for: arbiter.nextExpiry == nil ? .seconds(5) : .milliseconds(500))
        }
    }

    /// Drives whichever continuous meter the winning claim names.
    ///
    /// The meter is only started while it is actually showing: a system audio tap or a counter left
    /// running in the background would be work nobody asked for.
    private func followLiveMeter() async {
        var running: LiveMeterKind?
        var lastFrame = ContinuousClock.now

        while !Task.isCancelled {
            guard case .meter(let kind) = currentOutput, !isAsleep, connection != nil else {
                if let previous = running {
                    meter(for: previous).stop()
                    running = nil
                }
                try? await Task.sleep(for: .milliseconds(200))
                continue
            }

            let meter = meter(for: kind)
            if running != kind {
                running.map { self.meter(for: $0).stop() }
                do {
                    try meter.start()
                    running = kind
                    lastFrame = .now
                } catch {
                    if preferences.mode == .meter { preferences.mode = .off }
                    running = nil
                    continue
                }
            }

            let now = ContinuousClock.now
            let elapsed = max((now - lastFrame).blink1Milliseconds, 1)
            lastFrame = now

            if let levels = meter.levels(elapsed: Double(elapsed) / 1000) {
                let brightness = effectiveBrightness
                do {
                    try await coordinator.showLevels(left: meter.color(for: levels.left).dimmed(to: brightness),
                                                     right: meter.color(for: levels.right).dimmed(to: brightness),
                                                     fade: meter.fadeDuration)
                } catch {
                    connection = nil
                    appliedOutput = nil
                }
            }

            // The frame budget has to account for the USB traffic, or the loop drifts.
            let spent = (ContinuousClock.now - now).blink1Milliseconds
            let budget = Int(1000 / meter.frameRate)
            try? await Task.sleep(for: .milliseconds(max(budget - spent, 1)))
        }
    }

    private func blipIfANewHourStarted() async {
        let hour = Calendar.current.component(.hour, from: .now)
        defer { lastBlipHour = hour }
        guard let lastBlipHour, lastBlipHour != hour else { return }
        guard preferences.blipOnTheHour, currentOutput == .color(timeOfDayColor), !preferences.isNight() else { return }
        try? await coordinator.flash(.info, for: .seconds(3),
                                     thenReturningTo: currentOutput,
                                     brightness: effectiveBrightness,
                                     serialNumber: preferences.preferredSerialNumber)
    }

    private func connectIfNeeded() async {
        guard connection == nil else { return }
        do {
            connection = try await coordinator.connect(serialNumber: preferences.preferredSerialNumber,
                                                       brightness: effectiveBrightness)
            physicalResetAlertedSerialNumber = nil
            lastErrorMessage = nil
        } catch let error as Blink1Coordinator.PhysicalResetRequired {
            connection = nil
            lastErrorMessage = R.L.Device_RESET_STATUS
            guard physicalResetAlertedSerialNumber != error.serialNumber else { return }
            physicalResetAlertedSerialNumber = error.serialNumber
            PhysicalResetAlert.present(serialNumber: error.serialNumber)
        } catch let error as Blink1Error {
            connection = nil
            lastErrorMessage = error.description
        } catch {
            connection = nil
            lastErrorMessage = error.localizedDescription
        }
    }

    private func applyCurrentOutput() async {
        await apply(currentOutput, brightness: effectiveBrightness)
    }

    private func apply(_ output: DeviceOutput, brightness: Double) async {
        guard !isAsleep || output == .off else { return }
        await connectIfNeeded()
        guard connection != nil else { return }
        guard output != appliedOutput || brightness != appliedBrightness else { return }
        do {
            try await coordinator.apply(output, brightness: brightness,
                                        serialNumber: preferences.preferredSerialNumber)
            appliedOutput = output
            appliedBrightness = brightness
            lastErrorMessage = nil
        } catch let error as Blink1Error {
            appliedOutput = nil
            connection = nil
            lastErrorMessage = error.description
        } catch {
            appliedOutput = nil
            connection = nil
            lastErrorMessage = error.localizedDescription
        }
    }
}
