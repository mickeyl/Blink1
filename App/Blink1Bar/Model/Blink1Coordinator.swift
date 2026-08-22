import Blink1
import Foundation

/// Owns the blink(1) for the whole app.
///
/// A blink(1) answers one feature report at a time and has no notion of several clients, so exactly
/// one place may talk to it. Everything device-facing goes through this actor.
actor Blink1Coordinator {

    struct Connection: Equatable, Sendable {
        let serialNumber: String
        let productName: String
        let model: String
        let firmware: String
    }

    private var device: Blink1?
    /// The brightness the bank in the device was written with, to avoid needless rewrites.
    private var installedBrightness: Double?

    /// Devices currently attached — enumeration only, nothing is opened.
    func attachedDevices() -> [Blink1.Info] { Blink1.discover() }

    /// Opens the requested device (or the first one) and installs the signal bank into its RAM.
    ///
    /// The bank deliberately stays out of flash: the app writes it on every connect, which keeps the
    /// device's stored pattern untouched and lets the brightness change at will.
    @discardableResult
    func connect(serialNumber: String?, brightness: Double) throws -> Connection {
        if let device, serialNumber == nil || device.serialNumber == serialNumber {
            return try describe(device)
        }
        disconnect()
        let device = try serialNumber.map { try Blink1.open(serialNumber: $0) } ?? Blink1.open()
        self.device = device
        try device.installSignals(brightness: brightness)
        installedBrightness = brightness
        return try describe(device)
    }

    func disconnect() {
        device?.close()
        device = nil
        installedBrightness = nil
    }

    /// Applies an output, reconnecting once if the device went away in the meantime.
    func apply(_ output: DeviceOutput, brightness: Double, serialNumber: String?) throws {
        do {
            try send(output, brightness: brightness)
        } catch {
            // A device that was unplugged and plugged back in is a new IOKit object.
            disconnect()
            try connect(serialNumber: serialNumber, brightness: brightness)
            try send(output, brightness: brightness)
        }
    }

    /// Shows a signal for a moment, then returns to `output` — used for transient events.
    func flash(_ signal: Blink1.Signal, for duration: Duration,
               thenReturningTo output: DeviceOutput, brightness: Double, serialNumber: String?) async throws {
        try apply(.signal(signal), brightness: brightness, serialNumber: serialNumber)
        try? await Task.sleep(for: duration)
        try apply(output, brightness: brightness, serialNumber: serialNumber)
    }

    /// Pushes one stereo frame: top LED is the left channel, bottom the right.
    ///
    /// Bypasses `apply` deliberately — these values change every frame, so the "already applied"
    /// bookkeeping would only get in the way. The short fade lets the device interpolate between
    /// frames, which is what makes 30 updates a second look smooth rather than strobing.
    func showLevels(left: Blink1.Color, right: Blink1.Color, fade: Duration) throws {
        guard let device else { throw Blink1Error.noDeviceFound }
        try device.fade(to: left, over: fade, led: .top)
        try device.fade(to: right, over: fade, led: .bottom)
    }

    /// Checks whether the device still shows what it was told to show.
    ///
    /// The app is not the only thing that can reach the blink(1) — a CLI run with `--direct`, a test,
    /// or a glitch on the bus all leave the LED saying something the app never sent. Without this,
    /// the cached "already applied" state would keep it that way forever.
    func needsResync(for output: DeviceOutput, brightness: Double) -> Bool {
        guard let device else { return false }
        do {
            switch output {
                case .off:
                    return try !device.readColor().color.isBlack
                case .color(let color):
                    let expected = color.dimmed(to: brightness)
                    let actual = try device.readColor().color
                    return !Self.isClose(actual, expected)
                case .audio:
                    return false
                case .signal(let signal):
                    // A signal is a running pattern: the range it plays is the thing to compare.
                    let state = try device.readPlayState()
                    return !state.isPlaying
                        || state.startPosition != signal.slots.lowerBound
                        || state.endPosition != signal.slots.upperBound
            }
        } catch {
            return false
        }
    }

    /// PWM rounding makes the device report a value a step or two off what it was given.
    private static func isClose(_ one: Blink1.Color, _ other: Blink1.Color, tolerance: Int = 3) -> Bool {
        abs(Int(one.red) - Int(other.red)) <= tolerance
            && abs(Int(one.green) - Int(other.green)) <= tolerance
            && abs(Int(one.blue) - Int(other.blue)) <= tolerance
    }

    /// Re-arms the device-side watchdog. Only this command counts as a sign of life, so it has to be
    /// repeated well before the timeout runs out.
    func armWatchdog(timeout: Duration) throws {
        guard let device else { throw Blink1Error.noDeviceFound }
        try device.armWatchdog(timeout: timeout, showing: .hostGone)
    }

    func disarmWatchdog() {
        try? device?.disarmWatchdog()
    }

    private func send(_ output: DeviceOutput, brightness: Double) throws {
        guard let device else { throw Blink1Error.noDeviceFound }
        switch output {
            case .off:
                try device.stop()
                try device.turnOff()
            case .color(let color):
                // Stop first: a running pattern would paint over the color a moment later.
                try device.stop()
                try device.fade(to: color.dimmed(to: brightness), over: .milliseconds(250))
            case .audio:
                // Nothing to show yet: stop the pattern player so it cannot paint over the levels
                // that are about to be pushed frame by frame.
                try device.stop()
            case .signal(let signal):
                // Only signals care about the bank, and rewriting 32 slots is too much to do while a
                // brightness slider is being dragged.
                if installedBrightness != brightness {
                    try device.installSignals(brightness: brightness)
                    installedBrightness = brightness
                }
                try device.show(signal)
        }
    }

    private func describe(_ device: Blink1) throws -> Connection {
        Connection(serialNumber: device.serialNumber,
                   productName: device.info.productName,
                   model: device.model.description,
                   firmware: try device.firmwareVersionString())
    }
}
