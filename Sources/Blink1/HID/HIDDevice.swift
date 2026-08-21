import Foundation
import IOKit
import IOKit.hid

/// Minimal IOKit wrapper covering the only HID traffic a blink(1) speaks: feature reports.
///
/// blink(1) uses a vendor-defined usage page (0xFFAB), hence macOS grants access without
/// the "Input Monitoring" privilege that generic desktop/keyboard devices require.
final class HIDDevice {

    /// The `IOHIDManager` is kept alive alongside the device to keep the IOKit service references valid.
    private let manager: IOHIDManager
    private let device: IOHIDDevice
    private var isOpen = false

    private init(manager: IOHIDManager, device: IOHIDDevice) {
        self.manager = manager
        self.device = device
    }

    deinit { close() }

    static func devices(vendorID: Int, productID: Int) -> [HIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let criteria: [String: Any] = [kIOHIDVendorIDKey: vendorID, kIOHIDProductIDKey: productID]
        IOHIDManagerSetDeviceMatching(manager, criteria as CFDictionary)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        return devices.map { HIDDevice(manager: manager, device: $0) }
    }

    func property(_ key: String) -> Any? { IOHIDDeviceGetProperty(device, key as CFString) }

    var serialNumber: String? { property(kIOHIDSerialNumberKey) as? String }
    var productName: String? { property(kIOHIDProductKey) as? String }
    var locationID: UInt32? { (property(kIOHIDLocationIDKey) as? NSNumber)?.uint32Value }
    var maximumFeatureReportSize: Int? { (property(kIOHIDMaxFeatureReportSizeKey) as? NSNumber)?.intValue }

    func open() throws(HIDError) {
        guard !isOpen else { return }
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else { throw HIDError(result) }
        isOpen = true
    }

    func close() {
        guard isOpen else { return }
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        isOpen = false
    }

    /// Sends a feature report. `bytes[0]` must be the report ID, mirroring the on-the-wire layout.
    func setFeatureReport(_ bytes: [UInt8]) throws(HIDError) {
        guard let reportID = bytes.first else { throw HIDError.badArgument }
        let result = bytes.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, CFIndex(reportID), $0.baseAddress!, $0.count)
        }
        guard result == kIOReturnSuccess else { throw HIDError(result) }
    }

    /// Reads a feature report of `length` bytes, including the leading report ID byte.
    ///
    /// IOKit writes the report ID into byte 0 but counts only the payload in the returned length,
    /// hence the buffer is handed back in full rather than truncated to that count.
    func featureReport(id: UInt8, length: Int) throws(HIDError) -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: length)
        var reportLength = CFIndex(length)
        let result = buffer.withUnsafeMutableBufferPointer { pointer in
            IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, CFIndex(id), pointer.baseAddress!, &reportLength)
        }
        guard result == kIOReturnSuccess else { throw HIDError(result) }
        guard reportLength >= length - 1 else { throw HIDError(kIOReturnUnderrun) }
        return buffer
    }
}
