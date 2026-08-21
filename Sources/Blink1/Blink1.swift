import Foundation

/// A ThingM blink(1) USB RGB LED.
///
/// The device speaks a tiny command protocol carried in HID feature reports; see `Blink1+Report.swift`
/// for the wire format and `Blink1+Commands.swift` for the commands themselves.
///
/// ```swift
/// let blink1 = try Blink1.open()
/// try blink1.fade(to: .green, over: .milliseconds(250))
/// ```
///
/// Instances are not thread-safe: a device answers one feature report at a time.
public final class Blink1 {

    public static let vendorID = 0x27B8
    public static let productID = 0x01ED

    public let info: Info

    /// mk1 devices expect the host to apply the perceptual curve; later ones do it in firmware.
    public var appliesGammaCorrection: Bool

    let hid: HIDDevice
    private var cachedFirmwareVersion: Int?

    init(hid: HIDDevice, info: Info) throws(Blink1Error) {
        self.hid = hid
        self.info = info
        self.appliesGammaCorrection = !info.model.correctsGammaInFirmware
        do { try hid.open() } catch { throw Blink1Error(error) }
    }

    deinit { hid.close() }

    public func close() { hid.close() }

    public var model: Model { info.model }
    public var serialNumber: String { info.serialNumber }

    /// Firmware version scaled by 100, e.g. 306 for "v3.6". Read once, then cached.
    public func firmwareVersion() throws(Blink1Error) -> Int {
        if let cachedFirmwareVersion { return cachedFirmwareVersion }
        let response = try request(.version)
        guard response.count >= 5 else { throw .malformedResponse }
        let major = Int(response[3]) - Int(UInt8(ascii: "0"))
        let minor = Int(response[4]) - Int(UInt8(ascii: "0"))
        guard (0...9).contains(major), (0...9).contains(minor) else { throw .malformedResponse }
        let version = major * 100 + minor
        cachedFirmwareVersion = version
        return version
    }

    /// Human-readable firmware version, e.g. "3.6".
    public func firmwareVersionString() throws(Blink1Error) -> String {
        let version = try firmwareVersion()
        return "\(version / 100).\(version % 100)"
    }

    func requireFirmware(_ minimum: Int, feature: String) throws(Blink1Error) {
        let version = try firmwareVersion()
        guard version >= minimum else {
            throw .unsupported(feature: feature, by: "firmware \(version / 100).\(version % 100)")
        }
    }

    func require(_ capability: Bool, feature: String) throws(Blink1Error) {
        guard capability else { throw .unsupported(feature: feature, by: "blink(1) \(model)") }
    }
}
