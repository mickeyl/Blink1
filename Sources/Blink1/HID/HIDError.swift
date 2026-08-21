import Foundation
import IOKit

/// An `IOReturn` code raised while talking to the HID device, translated into something readable.
struct HIDError: Error, CustomStringConvertible {

    let code: IOReturn

    init(_ code: IOReturn) { self.code = code }

    static let badArgument = HIDError(kIOReturnBadArgument)

    var isPermissionDenied: Bool { code == kIOReturnNotPermitted || code == kIOReturnNotPrivileged }
    var isExclusiveAccess: Bool { code == kIOReturnExclusiveAccess || code == kIOReturnBusy }

    var description: String {
        switch code {
            case kIOReturnNotPermitted, kIOReturnNotPrivileged: "access to the device was denied by the system"
            case kIOReturnExclusiveAccess, kIOReturnBusy: "the device is claimed by another process"
            case kIOReturnNoDevice, kIOReturnNotAttached: "the device went away"
            case kIOReturnUnsupported: "the device does not support this request"
            case kIOReturnTimeout: "the device did not answer in time"
            case kIOReturnBadArgument: "invalid report"
            default: "IOKit error 0x\(String(UInt32(bitPattern: code), radix: 16))"
        }
    }
}
