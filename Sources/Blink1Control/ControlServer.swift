import Dispatch
import Foundation

/// Listens on the control socket and hands every request to the app.
///
/// One connection carries one request and one answer, then closes — the clients are short-lived
/// scripts, and a connection that outlives them would only be something to clean up later.
public final class ControlServer: @unchecked Sendable {

    public typealias Handler = @Sendable (ControlRequest) async -> ControlResponse

    private let path: URL
    private let queue = DispatchQueue(label: "de.vanille.Blink1Bar.control")
    private var descriptor: Int32 = -1
    private var source: DispatchSourceRead?

    public init(path: URL = ControlSocket.defaultPath) {
        self.path = path
    }

    deinit { stop() }

    public func start(handler: @escaping Handler) throws {
        stop()
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        // A socket file left behind by a crash would block bind() forever.
        try? FileManager.default.removeItem(at: path)

        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw Failure.posix("socket", errno) }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let socketPath = path.path(percentEncoded: false)
        guard socketPath.utf8.count < MemoryLayout.size(ofValue: address.sun_path) else {
            close(descriptor)
            throw Failure.pathTooLong
        }
        _ = withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            socketPath.withCString { source in
                strcpy(UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: CChar.self), source)
            }
        }

        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                bind(descriptor, address, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else {
            close(descriptor)
            throw Failure.posix("bind", errno)
        }
        guard listen(descriptor, 8) == 0 else {
            close(descriptor)
            throw Failure.posix("listen", errno)
        }
        // Only this user may command the LED.
        chmod(socketPath, 0o600)

        self.descriptor = descriptor
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptConnection(handler: handler) }
        source.resume()
        self.source = source
    }

    public func stop() {
        source?.cancel()
        source = nil
        if descriptor >= 0 {
            close(descriptor)
            descriptor = -1
        }
        try? FileManager.default.removeItem(at: path)
    }

    private func acceptConnection(handler: @escaping Handler) {
        let client = accept(descriptor, nil, nil)
        guard client >= 0 else { return }

        var request = Data()
        var chunk = [UInt8](repeating: 0, count: 1_024)
        while !request.contains(ControlSocket.terminator) {
            let count = read(client, &chunk, chunk.count)
            guard count > 0 else { break }
            request.append(contentsOf: chunk[0..<count])
        }

        guard let line = request.split(separator: ControlSocket.terminator).first,
              let decoded = try? JSONDecoder().decode(ControlRequest.self, from: Data(line)) else {
            respond(.failure("unreadable request"), to: client)
            return
        }

        Task {
            let response = await handler(decoded)
            self.respond(response, to: client)
        }
    }

    private func respond(_ response: ControlResponse, to client: Int32) {
        defer { close(client) }
        guard let data = try? ControlSocket.encode(response) else { return }
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            var sent = 0
            while sent < buffer.count {
                let written = write(client, buffer.baseAddress!.advanced(by: sent), buffer.count - sent)
                guard written > 0 else { return }
                sent += written
            }
        }
    }

    public enum Failure: Error, CustomStringConvertible {

        case posix(String, Int32)
        case pathTooLong

        public var description: String {
            switch self {
                case .posix(let call, let code): "\(call) failed: \(String(cString: strerror(code)))"
                case .pathTooLong: "the socket path is too long"
            }
        }
    }
}
