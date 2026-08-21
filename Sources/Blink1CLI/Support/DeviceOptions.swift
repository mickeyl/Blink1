import ArgumentParser
import Blink1
import Foundation

/// How a command talks back, shared by everything that prints.
struct OutputOptions: ParsableArguments {

    @Flag(name: .long, help: "Never colorize output.")
    var noColor = false

    @Flag(name: [.customShort("q"), .long], help: "Suppress status messages.")
    var quiet = false

    func apply() {
        Terminal.colorSuppressed = noColor
        Terminal.quiet = quiet
    }
}

/// Options every device-touching subcommand shares.
struct DeviceOptions: ParsableArguments {

    @Option(name: [.customShort("d"), .long],
            help: ArgumentHelp("Serial number (8 hex digits) or index from `blink1 list`.", valueName: "device"))
    var device: String?

    @OptionGroup var output: OutputOptions

    /// Opens the selected device and hands it to `body`, turning library errors into tidy exits.
    func withDevice<T>(_ body: (Blink1) throws -> T) throws -> T {
        output.apply()
        do {
            let blink1 = try open()
            defer { blink1.close() }
            return try body(blink1)
        } catch let error as Blink1Error {
            Terminal.failure(error.description, hint: error.hint)
            throw ExitCode(error.exitCode)
        }
    }

    private func open() throws(Blink1Error) -> Blink1 {
        guard let device else { return try Blink1.open() }
        // Serial numbers are 8 hex digits, so a short decimal number can only mean an index.
        if device.count <= 2, let index = Int(device) { return try Blink1.open(index: index) }
        return try Blink1.open(serialNumber: device)
    }
}

extension Blink1Error {

    /// Exit codes scripts can branch on; 64 is reserved by ArgumentParser for usage errors.
    var exitCode: Int32 {
        switch self {
            case .noDeviceFound, .deviceNotFound: 2
            case .accessDenied, .deviceBusy: 3
            default: 1
        }
    }

    var hint: String? {
        switch self {
            case .noDeviceFound, .deviceNotFound:
                "Plug in a blink(1) and check `blink1 list`."
            case .deviceBusy, .accessDenied:
                "Another program may hold the device — quit Blink1Control or a running `blink1` process."
            case .unsupported:
                "Run `blink1 info` to see what this device supports."
            default:
                nil
        }
    }
}
