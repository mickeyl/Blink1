import Foundation

extension Blink1 {

    /// Number of pattern slots this device offers.
    public var patternSlots: Int { model.patternSlots }

    /// Writes one pattern line into the device's RAM.
    ///
    /// - Note: mk1 stores every line in flash right away, mk2 and later need `savePattern()`.
    /// - Note: The per-line LED is a separate "set led" command that the firmware keeps as a sticky
    ///         modifier for following writes, so it is always sent — otherwise a line would silently
    ///         inherit the LED of whatever was written before it. Firmware 204 and later only.
    public func writePatternLine(_ line: PatternLine, at position: UInt8) throws(Blink1Error) {
        try requirePatternPosition(position)
        if model.supportsIndividualLEDs, try firmwareVersion() >= 204 {
            try send(.setLED, line.led.rawValue)
        } else if line.led != .all {
            throw .unsupported(feature: "addressing a single LED", by: "blink(1) \(model)")
        }
        let color = transmittable(line.color)
        let ticks = line.fadeDuration.blink1Ticks
        try send(.writePatternLine, color.red, color.green, color.blue,
                 UInt8(ticks >> 8), UInt8(ticks & 0xFF), position)
    }

    public func readPatternLine(at position: UInt8) throws(Blink1Error) -> PatternLine {
        try requirePatternPosition(position)
        let response = try request(.readPatternLine, 0, 0, 0, 0, 0, position)
        let ticks = UInt16(response[5]) << 8 | UInt16(response[6])
        return PatternLine(color: Color(red: response[2], green: response[3], blue: response[4]),
                           fadeDuration: Duration(blink1Ticks: ticks),
                           led: LED(rawValue: response[7]) ?? .all)
    }

    /// Reads the whole on-device pattern.
    public func readPattern() throws(Blink1Error) -> [PatternLine] {
        var lines: [PatternLine] = []
        for position in 0..<UInt8(patternSlots) {
            lines.append(try readPatternLine(at: position))
        }
        return lines
    }

    /// Writes consecutive pattern lines, starting at `position`.
    public func writePattern(_ lines: [PatternLine], startingAt position: UInt8 = 0) throws(Blink1Error) {
        for (offset, line) in lines.enumerated() {
            try writePatternLine(line, at: position + UInt8(offset))
        }
    }

    /// Persists the pattern currently held in RAM to flash, surviving a power cycle.
    ///
    /// The device stalls USB while erasing flash, so the write is fire-and-forget: a transport error
    /// here is expected behaviour, not a failure.
    public func savePattern() throws(Blink1Error) {
        try require(model != .mk1, feature: "saving patterns (mk1 saves each line immediately)")
        do {
            try send(.savePatterns, 0xBE, 0xEF, 0xCA, 0xFE)
        } catch {
            // a stalled transfer is expected: flash programming outlasts the USB control transfer timeout
            guard case .transportFailure = error else { throw error }
        }
        Thread.sleep(forTimeInterval: 0.1)
    }

    /// Plays the stored pattern.
    ///
    /// - Note: The end position is inclusive — `play(0...1)` plays slots 0 and 1.
    /// - Note: The firmware reads an end position of 0 as "play the whole pattern", so slot 0 cannot
    ///         be played on its own. `play(0...0)` throws rather than quietly playing everything.
    /// - Parameters:
    ///   - range: slots to play; the full pattern when omitted.
    ///   - repeats: 0 repeats endlessly.
    public func play(_ range: ClosedRange<UInt8>? = nil, repeats: UInt8 = 0) throws(Blink1Error) {
        let lastSlot = UInt8(patternSlots - 1)
        let start = range?.lowerBound ?? 0
        let end = range?.upperBound ?? lastSlot
        try requirePatternPosition(start)
        try requirePatternPosition(end)
        guard end != 0 else {
            throw .outOfRange("slot 0 on its own — the firmware reads an end position of 0 as "
                + "'play the whole pattern'. Give the range at least two slots.")
        }
        if start != 0 || end != lastSlot || repeats != 0 {
            try require(model.supportsPatternLoop, feature: "playing a pattern sub-range")
        }
        try send(.playLoop, 1, start, end, repeats)
    }

    public func stop() throws(Blink1Error) {
        try send(.playLoop, 0, 0, 0, 0)
    }

    public func readPlayState() throws(Blink1Error) -> PlayState {
        try require(model.supportsPatternLoop, feature: "reading the play state")
        let response = try request(.readPlayState)
        return PlayState(isPlaying: response[2] != 0,
                         startPosition: response[3],
                         endPosition: response[4],
                         remainingRepeats: response[5],
                         currentPosition: response[6])
    }

    private func requirePatternPosition(_ position: UInt8) throws(Blink1Error) {
        guard Int(position) < patternSlots else {
            throw .outOfRange("pattern position \(position), device has \(patternSlots) slots")
        }
    }
}
