import Foundation

extension Blink1 {

    /// All attached blink(1) devices, ordered by serial number for a stable device index.
    public static func discover() -> [Info] {
        attachedDevices().map(\.1)
    }

    /// Opens the first attached device.
    public static func open() throws(Blink1Error) -> Blink1 {
        guard let (hid, info) = attachedDevices().first else { throw .noDeviceFound }
        return try Blink1(hid: hid, info: info)
    }

    /// Opens the device with the given serial number (case-insensitive, 8 hex digits).
    public static func open(serialNumber: String) throws(Blink1Error) -> Blink1 {
        let wanted = serialNumber.lowercased()
        guard let (hid, info) = attachedDevices().first(where: { $0.1.serialNumber.lowercased() == wanted }) else {
            throw .deviceNotFound(serialNumber: serialNumber)
        }
        return try Blink1(hid: hid, info: info)
    }

    /// Opens the device at the given position of `discover()`.
    public static func open(index: Int) throws(Blink1Error) -> Blink1 {
        let devices = attachedDevices()
        guard devices.indices.contains(index) else {
            throw devices.isEmpty ? .noDeviceFound : .outOfRange("device index \(index), \(devices.count) attached")
        }
        let (hid, info) = devices[index]
        return try Blink1(hid: hid, info: info)
    }

    public static func openAll() throws(Blink1Error) -> [Blink1] {
        var devices: [Blink1] = []
        for (hid, info) in attachedDevices() {
            devices.append(try Blink1(hid: hid, info: info))
        }
        return devices
    }

    private static func attachedDevices() -> [(HIDDevice, Info)] {
        HIDDevice.devices(vendorID: vendorID, productID: productID)
            .compactMap { device in
                guard let serialNumber = device.serialNumber else { return nil }
                let info = Info(serialNumber: serialNumber,
                                productName: device.productName ?? "blink(1)",
                                locationID: device.locationID)
                return (device, info)
            }
            .sorted { $0.1.serialNumber < $1.1.serialNumber }
    }
}
