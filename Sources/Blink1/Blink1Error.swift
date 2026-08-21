import Foundation

public enum Blink1Error: Error, CustomStringConvertible, Sendable {

    /// No blink(1) is attached to this machine.
    case noDeviceFound
    /// A blink(1) with the given serial number is not attached.
    case deviceNotFound(serialNumber: String)
    /// The system refused access to the device.
    case accessDenied
    /// Another process holds the device exclusively.
    case deviceBusy
    /// Low-level transport failure.
    case transportFailure(String)
    /// The device answered with something unexpected (wrong echo, short report).
    case malformedResponse
    /// The attached hardware or firmware lacks the requested feature.
    case unsupported(feature: String, by: String)
    /// A parameter exceeds what the protocol can encode.
    case outOfRange(String)

    public var description: String {
        switch self {
            case .noDeviceFound: "no blink(1) found"
            case .deviceNotFound(let serial): "no blink(1) with serial number \(serial) found"
            case .accessDenied: "access to the blink(1) was denied by the system"
            case .deviceBusy: "the blink(1) is claimed by another process"
            case .transportFailure(let detail): "USB transfer failed: \(detail)"
            case .malformedResponse: "the blink(1) sent an unexpected answer"
            case .unsupported(let feature, let device): "\(feature) is not supported by \(device)"
            case .outOfRange(let detail): "value out of range: \(detail)"
        }
    }

    init(_ error: HIDError) {
        self = if error.isPermissionDenied { .accessDenied }
        else if error.isExclusiveAccess { .deviceBusy }
        else { .transportFailure(error.description) }
    }
}
