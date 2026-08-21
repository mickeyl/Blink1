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
            Task { await applyCurrentOutput() }
        }
    }

    private(set) var connection: Blink1Coordinator.Connection?
    private(set) var attachedDevices: [Blink1.Info] = []
    private(set) var lastErrorMessage: String?
    /// Recomputed on the clock so the menu can show the color the device is fading through.
    private(set) var timeOfDayColor: Blink1.Color = TimeOfDayPalette.color()

    private let coordinator = Blink1Coordinator()
    private let powerMonitor = PowerMonitor()
    private let controlServer = ControlServer()
    private var appliedOutput: DeviceOutput?
    private var appliedBrightness: Double?
    private var lastBlipHour: Int?
    private var isAsleep = false
    private var tasks: [Task<Void, Never>] = []

    /// The watchdog has to be re-armed well inside its own timeout, or it fires on a healthy app.
    private static let watchdogTimeout = Duration.seconds(30)
    private static let watchdogHeartbeat = Duration.seconds(10)

    init() {
        self.preferences = .load()
    }

    var isConnected: Bool { connection != nil }

    /// What the LED should show, given the current settings and the time.
    var currentOutput: DeviceOutput {
        switch preferences.mode {
            case .off: .off
            case .color: .color(preferences.staticColor)
            case .signal: .signal(preferences.signal)
            case .timeOfDay: .color(timeOfDayColor)
        }
    }

    var effectiveBrightness: Double { preferences.effectiveBrightness() }

    // MARK: - Lifecycle

    func start() {
        guard tasks.isEmpty else { return }
        tasks.append(Task { await self.watchForDevices() })
        tasks.append(Task { await self.followTheClock() })
        tasks.append(Task { await self.feedTheWatchdog() })
        powerMonitor.start(onSleep: { [weak self] in self?.handleSleep() },
                           onWake: { [weak self] in self?.handleWake() })
        startControlServer()
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
                try? await coordinator.armWatchdog(timeout: Self.watchdogTimeout)
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
            case .off, .signal: break
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
        guard await coordinator.needsResync(for: currentOutput, brightness: effectiveBrightness) else { return }
        appliedOutput = nil
    }

    private func blipIfANewHourStarted() async {
        let hour = Calendar.current.component(.hour, from: .now)
        defer { lastBlipHour = hour }
        guard let lastBlipHour, lastBlipHour != hour else { return }
        guard preferences.blipOnTheHour, preferences.mode == .timeOfDay, !preferences.isNight() else { return }
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
            lastErrorMessage = nil
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
