import Foundation

extension Blink1 {

    /// The command byte, an ASCII character, that occupies byte 1 of every report.
    enum Command: UInt8 {

        case fadeToRGB = 0x63            // 'c'
        case setRGBNow = 0x6E            // 'n'
        case readRGB = 0x72              // 'r'
        case serverDown = 0x44           // 'D'
        case playLoop = 0x70             // 'p'
        case readPlayState = 0x53        // 'S'
        case writePatternLine = 0x50     // 'P'
        case savePatterns = 0x57         // 'W'
        case readPatternLine = 0x52      // 'R'
        case setLED = 0x6C               // 'l'
        case readEEPROM = 0x65           // 'e', mk1 only
        case writeEEPROM = 0x45          // 'E', mk1 only
        case version = 0x76              // 'v'
        case selfTest = 0x21             // '!'
        case setStartupParameters = 0x42 // 'B'
        case getStartupParameters = 0x62 // 'b'
        case writeNote = 0x46            // 'F', report 2
        case readNote = 0x66             // 'f', report 2
        case chipID = 0x55               // 'U', report 2
        case goToBootloader = 0x47       // 'G'
        case lockBootloader = 0x4C       // 'L', report 2
    }

    /// Report 1 carries 8 bytes: report id, command, six arguments.
    public static let reportID: UInt8 = 1
    public static let reportSize = 9
    /// Report 2 (mk3 and later) carries 60 bytes and is used for notes, chip id and bootloader control.
    public static let extendedReportID: UInt8 = 2
    public static let extendedReportSize = 61

    /// A command without an answer.
    func send(_ command: Command, _ arguments: UInt8...) throws(Blink1Error) {
        try write(report(id: Self.reportID, size: Self.reportSize, command: command, payload: arguments))
    }

    /// A command whose answer is fetched with a subsequent GET_REPORT, as the firmware expects.
    @discardableResult
    func request(_ command: Command, _ arguments: UInt8...) throws(Blink1Error) -> [UInt8] {
        try write(report(id: Self.reportID, size: Self.reportSize, command: command, payload: arguments))
        return try read(id: Self.reportID, size: Self.reportSize)
    }

    func sendExtended(_ command: Command, _ payload: [UInt8]) throws(Blink1Error) {
        try write(report(id: Self.extendedReportID, size: Self.extendedReportSize, command: command, payload: payload))
    }

    @discardableResult
    func requestExtended(_ command: Command, _ payload: [UInt8]) throws(Blink1Error) -> [UInt8] {
        try write(report(id: Self.extendedReportID, size: Self.extendedReportSize, command: command, payload: payload))
        return try read(id: Self.extendedReportID, size: Self.extendedReportSize)
    }

    private func report(id: UInt8, size: Int, command: Command, payload: [UInt8]) -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: size)
        buffer[0] = id
        buffer[1] = command.rawValue
        for (index, byte) in payload.prefix(size - 2).enumerated() { buffer[index + 2] = byte }
        return buffer
    }

    private func write(_ buffer: [UInt8]) throws(Blink1Error) {
        do { try hid.setFeatureReport(buffer) } catch { throw Blink1Error(error) }
    }

    private func read(id: UInt8, size: Int) throws(Blink1Error) -> [UInt8] {
        do {
            let response = try hid.featureReport(id: id, length: size)
            guard response.count == size else { throw Blink1Error.malformedResponse }
            return response
        } catch let error as HIDError {
            throw Blink1Error(error)
        } catch {
            throw .malformedResponse
        }
    }

    /// Applies the perceptual curve where the hardware does not.
    func transmittable(_ color: Color) -> Color {
        guard appliesGammaCorrection else { return color }
        return Color(red: Gamma.corrected(color.red),
                     green: Gamma.corrected(color.green),
                     blue: Gamma.corrected(color.blue))
    }
}
