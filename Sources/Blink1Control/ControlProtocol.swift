import Foundation

/// The vocabulary between whatever produces a status and the app that owns the device.
///
/// A blink(1) has one owner: several processes writing to it at once just overwrite each other. So
/// scripts, hooks and the CLI do not talk to the device while the app runs — they say what happened
/// and let the app decide what the LED shows.
public enum ControlRequest: Codable, Sendable, Equatable {

    /// What is the app showing right now?
    case status
    case off
    /// A signal by name, e.g. "error".
    case signal(String)
    /// A steady color, written the way the CLI accepts it: "#ff8800", "red", "255,136,0".
    case color(String)
    /// Hand control back to the clock.
    case clock
}

public struct ControlResponse: Codable, Sendable, Equatable {

    public var ok: Bool
    /// The mode the app is in afterwards: "off", "color", "signal" or "clock".
    public var mode: String?
    /// What that mode shows — a signal name or a hex color.
    public var detail: String?
    /// Serial number of the device being driven, if one is attached.
    public var device: String?
    public var error: String?

    public init(ok: Bool, mode: String? = nil, detail: String? = nil, device: String? = nil, error: String? = nil) {
        self.ok = ok
        self.mode = mode
        self.detail = detail
        self.device = device
        self.error = error
    }

    public static func failure(_ message: String) -> ControlResponse {
        ControlResponse(ok: false, error: message)
    }
}

public enum ControlSocket {

    /// Where the app listens. One socket per user, outside any sandbox container.
    public static var defaultPath: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Application Support")
        return base.appending(path: "Blink1Bar/control.sock")
    }

    /// Requests and responses are one JSON object per line, so both ends can read to a newline and
    /// be done — no length prefixes, no framing to get wrong.
    static let terminator = UInt8(ascii: "\n")

    static func encode(_ value: some Encodable) throws -> Data {
        var data = try JSONEncoder().encode(value)
        data.append(terminator)
        return data
    }
}
