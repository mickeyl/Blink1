import Foundation

/// Sends one request to a running Blink1Bar and waits for its answer.
///
/// Deliberately blocking and short-lived: callers are scripts and CLI invocations that do one thing
/// and exit. If nothing is listening, `send` throws `notRunning` and the caller can fall back to
/// driving the device itself.
public enum ControlClient {

    public enum Failure: Error, CustomStringConvertible {

        case notRunning
        case transport(String)
        case malformedResponse

        public var description: String {
            switch self {
                case .notRunning: "Blink1Bar is not running"
                case .transport(let detail): "could not talk to Blink1Bar: \(detail)"
                case .malformedResponse: "Blink1Bar sent an unexpected answer"
            }
        }
    }

    public static func send(_ request: ControlRequest,
                            to path: URL = ControlSocket.defaultPath,
                            timeout: TimeInterval = 2) throws(Failure) -> ControlResponse {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw .transport(String(cString: strerror(errno))) }
        defer { close(descriptor) }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let socketPath = path.path(percentEncoded: false)
        guard socketPath.utf8.count < MemoryLayout.size(ofValue: address.sun_path) else {
            throw .transport("socket path is too long")
        }
        _ = withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            socketPath.withCString { source in
                strcpy(UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: CChar.self), source)
            }
        }

        var timeoutValue = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeoutValue, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeoutValue, socklen_t(MemoryLayout<timeval>.size))

        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                connect(descriptor, address, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            // No socket, or nobody accepting: the app simply is not there.
            throw errno == ENOENT || errno == ECONNREFUSED ? .notRunning : .transport(String(cString: strerror(errno)))
        }

        let payload: Data
        do { payload = try ControlSocket.encode(request) } catch { throw .transport("\(error)") }
        try payload.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) throws(Failure) in
            var sent = 0
            while sent < buffer.count {
                let written = write(descriptor, buffer.baseAddress!.advanced(by: sent), buffer.count - sent)
                guard written > 0 else { throw .transport(String(cString: strerror(errno))) }
                sent += written
            }
        }

        var response = Data()
        var chunk = [UInt8](repeating: 0, count: 1_024)
        while !response.contains(ControlSocket.terminator) {
            let count = read(descriptor, &chunk, chunk.count)
            guard count > 0 else { break }
            response.append(contentsOf: chunk[0..<count])
        }
        guard let line = response.split(separator: ControlSocket.terminator).first,
              let decoded = try? JSONDecoder().decode(ControlResponse.self, from: Data(line)) else {
            throw .malformedResponse
        }
        return decoded
    }
}
