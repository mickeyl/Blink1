import Foundation

extension Blink1 {

    /// Writes every signal into the device's pattern memory.
    ///
    /// - Parameters:
    ///   - brightness: scales all colors, 0…1.
    ///   - persist: also write the bank to flash, so it survives unplugging. This replaces whatever
    ///     pattern the device shipped with, which cannot be read back afterwards.
    public func installSignals(brightness: Double = 1, persist: Bool = false) throws(Blink1Error) {
        try require(patternSlots >= Signal.requiredSlots,
                    feature: "the signal bank, which needs \(Signal.requiredSlots) pattern slots")
        for signal in Signal.allCases {
            try writePattern(signal.steps(brightness: brightness), startingAt: signal.slots.lowerBound)
        }
        if persist { try savePattern() }
    }

    /// Plays a signal — one command, no pattern writing, and the device carries on by itself.
    public func show(_ signal: Signal) throws(Blink1Error) {
        try play(signal.slots, repeats: signal.repeats)
    }

    /// Points the watchdog at a signal: when nothing re-arms it in time, the device shows that signal
    /// on its own. Only `armWatchdog` counts as a sign of life, so call this from a heartbeat.
    public func armWatchdog(timeout: Duration, showing signal: Signal = .hostGone) throws(Blink1Error) {
        try armWatchdog(timeout: timeout, keepsColor: true, pattern: signal.slots)
    }

    /// Makes the device show a signal the moment it gets power, before any software runs.
    public func setStartupSignal(_ signal: Signal) throws(Blink1Error) {
        try setStartupConfiguration(.init(mode: .play,
                                          startPosition: signal.slots.lowerBound,
                                          endPosition: signal.slots.upperBound,
                                          repeats: signal.repeats))
    }
}
