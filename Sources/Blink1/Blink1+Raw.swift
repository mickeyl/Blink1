import Foundation

extension Blink1 {

    /// Sends a raw feature report, for firmware features this library does not model yet.
    ///
    /// `payload` is everything after the report ID: command byte first, arguments after it.
    /// It is zero-padded (or truncated) to the report size.
    public func sendRaw(_ payload: [UInt8], reportID: UInt8 = Blink1.reportID) throws(Blink1Error) {
        try writeRaw(rawReport(payload, reportID: reportID))
    }

    /// Sends a raw feature report and reads the device's answer, including the leading report ID byte.
    public func requestRaw(_ payload: [UInt8], reportID: UInt8 = Blink1.reportID) throws(Blink1Error) -> [UInt8] {
        let size = reportID == Blink1.extendedReportID ? Blink1.extendedReportSize : Blink1.reportSize
        try writeRaw(rawReport(payload, reportID: reportID))
        return try readRaw(id: reportID, size: size)
    }

    private func rawReport(_ payload: [UInt8], reportID: UInt8) -> [UInt8] {
        let size = reportID == Blink1.extendedReportID ? Blink1.extendedReportSize : Blink1.reportSize
        var buffer = [UInt8](repeating: 0, count: size)
        buffer[0] = reportID
        for (index, byte) in payload.prefix(size - 1).enumerated() { buffer[index + 1] = byte }
        return buffer
    }

    private func writeRaw(_ buffer: [UInt8]) throws(Blink1Error) {
        do { try hid.setFeatureReport(buffer) } catch { throw Blink1Error(error) }
    }

    private func readRaw(id: UInt8, size: Int) throws(Blink1Error) -> [UInt8] {
        do { return try hid.featureReport(id: id, length: size) } catch { throw Blink1Error(error) }
    }
}
