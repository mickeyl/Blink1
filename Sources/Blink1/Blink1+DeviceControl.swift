import Foundation

extension Blink1 {

    // MARK: - Watchdog ("serverdown")

    /// Arms the device-side watchdog: unless another command arrives within `timeout`, the blink(1)
    /// switches to `pattern` (or turns off) on its own — the classic "is my server still alive?" signal.
    ///
    /// Re-arm it periodically ("tickle") by calling this again.
    ///
    /// Only this command re-arms the timer — other traffic does not count as a sign of life.
    ///
    /// - Parameters:
    ///   - timeout: up to ~10.9 minutes; firmware 204 caps out around 62 seconds.
    ///   - keepsColor: mk2 and later. Passing `false` blanks the LED immediately on arming, not just
    ///     when the watchdog fires, so pass `true` to keep showing the current status.
    ///   - pattern: sub-range to play when firing, requires firmware 205 or later.
    public func armWatchdog(timeout: Duration,
                            keepsColor: Bool = false,
                            pattern: ClosedRange<UInt8>? = nil) throws(Blink1Error) {
        let ticks = timeout.blink1Ticks
        try send(.serverDown, 1, UInt8(ticks >> 8), UInt8(ticks & 0xFF),
                 keepsColor ? 1 : 0, pattern?.lowerBound ?? 0, pattern?.upperBound ?? 0)
    }

    /// Disarms the watchdog.
    public func disarmWatchdog() throws(Blink1Error) {
        try send(.serverDown, 0, 0, 0, 0, 0, 0)
    }

    // MARK: - Power-on behaviour

    /// What the device does when it gets power. Requires firmware 206 or later.
    public func startupConfiguration() throws(Blink1Error) -> StartupConfiguration {
        try requireFirmware(206, feature: "startup parameters")
        let response = try request(.getStartupParameters)
        return StartupConfiguration(mode: StartupConfiguration.Mode(rawValue: response[2]) ?? .normal,
                                    startPosition: response[3],
                                    endPosition: response[4],
                                    repeats: response[5])
    }

    /// Stores the power-on behaviour in flash. Requires firmware 206 or later.
    public func setStartupConfiguration(_ configuration: StartupConfiguration) throws(Blink1Error) {
        try requireFirmware(206, feature: "startup parameters")
        try send(.setStartupParameters, configuration.mode.rawValue,
                 configuration.startPosition, configuration.endPosition, configuration.repeats)
    }

    // MARK: - Notes (mk3 and later)

    /// Bytes of free-form storage per note slot.
    public static let noteSize = 50

    /// Stores 50 bytes of arbitrary data in the device — handy to tag a blink(1) with its purpose.
    public func writeNote(_ note: [UInt8], id: UInt8) throws(Blink1Error) {
        try require(model.supportsNotes, feature: "notes")
        guard note.count <= Self.noteSize else { throw .outOfRange("note of \(note.count) bytes, limit is \(Self.noteSize)") }
        var payload = [UInt8](repeating: 0, count: Self.noteSize + 1)
        payload[0] = id
        for (index, byte) in note.enumerated() { payload[index + 1] = byte }
        try sendExtended(.writeNote, payload)
    }

    /// Convenience for text notes; the string is stored UTF-8 encoded and zero padded.
    public func writeNote(_ text: String, id: UInt8) throws(Blink1Error) {
        let bytes = Array(text.utf8)
        guard bytes.count <= Self.noteSize else { throw .outOfRange("note of \(bytes.count) bytes, limit is \(Self.noteSize)") }
        try writeNote(bytes, id: id)
    }

    public func readNote(id: UInt8) throws(Blink1Error) -> [UInt8] {
        try require(model.supportsNotes, feature: "notes")
        let response = try requestExtended(.readNote, [id])
        return Array(response[3..<(3 + Self.noteSize)])
    }

    /// The note interpreted as UTF-8 text, trailing padding removed.
    public func readNoteText(id: UInt8) throws(Blink1Error) -> String {
        let bytes = try readNote(id: id).prefix { $0 != 0 }
        return String(decoding: bytes, as: UTF8.self)
    }

    // MARK: - Identity and diagnostics

    /// The MCU's unique id (mk3 and later).
    public func chipID() throws(Blink1Error) -> String {
        try require(model.supportsNotes, feature: "reading the chip id")
        let response = try requestExtended(.chipID, [])
        return response[2...].prefix { $0 != 0 }.map { String(format: "%02x", $0) }.joined()
    }

    /// Round-trips a report to verify the transport; returns the device's raw answer.
    @discardableResult
    public func selfTest() throws(Blink1Error) -> [UInt8] {
        try request(.selfTest)
    }

    // MARK: - mk1 EEPROM

    public func readEEPROM(address: UInt8) throws(Blink1Error) -> UInt8 {
        try require(model == .mk1, feature: "EEPROM access")
        let response = try request(.readEEPROM, address)
        return response[3]
    }

    public func writeEEPROM(address: UInt8, value: UInt8) throws(Blink1Error) {
        try require(model == .mk1, feature: "EEPROM access")
        try send(.writeEEPROM, address, value)
    }

    // MARK: - Bootloader (mk3 and later)

    /// Reboots into the USB bootloader for a firmware update. The device disappears from the bus
    /// until it is re-plugged or the update finishes.
    ///
    /// - Note: The reference implementation sends this on report 2, unlike the command table in the
    ///         protocol document, which shows report 1.
    public func enterBootloader() throws(Blink1Error) {
        try require(model.supportsNotes, feature: "the bootloader command")
        let response = try requestExtended(.goToBootloader, Array("oBoot".utf8))
        guard response.count > 7, Array(response[1..<7]) == Array("GOBOOT".utf8) else {
            throw .unsupported(feature: "entering the bootloader", by: "this device (bootloader locked)")
        }
    }

    /// Permanently disables `enterBootloader()`. **Irreversible in software** — only a hardware
    /// modification brings the bootloader back. Firmware updates become impossible.
    public func lockBootloader() throws(Blink1Error) {
        try require(model.supportsNotes, feature: "locking the bootloader")
        let response = try requestExtended(.lockBootloader, Array("ockBootload".utf8))
        guard response.count > 7, Array(response[1..<7]) == Array("LOCKED".utf8) else {
            throw .malformedResponse
        }
    }
}
