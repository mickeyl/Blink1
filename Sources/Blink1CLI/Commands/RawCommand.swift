import ArgumentParser
import Blink1

struct RawCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "raw",
        abstract: "Send a raw feature report — for protocol work.",
        discussion: """
        Bytes are hex, the first one is the command character's code, the rest are its arguments;
        the report ID is prepended for you and missing bytes are zero-filled.

          blink1 raw 63 ff 00 00 00 0a 00     fade to red over 100ms ('c')
          blink1 raw --read 76                read the firmware version ('v')
          blink1 raw --report 2 --read 55     read the chip id ('U')
        """)

    @Argument(help: ArgumentHelp("Report bytes in hex, without the report ID.", valueName: "byte"))
    var bytes: [String] = []

    @Flag(name: [.customShort("r"), .long], help: "Read the device's answer after sending.")
    var read = false

    @Option(name: .long, help: "Report ID: 1 for regular commands, 2 for mk3 extras.")
    var report: UInt8 = 1

    @OptionGroup var options: DeviceOptions

    func validate() throws {
        guard !bytes.isEmpty else { throw ValidationError("give at least the command byte, e.g. 76 for 'v'") }
        guard bytes.allSatisfy({ UInt8($0, radix: 16) != nil }) else {
            throw ValidationError("all bytes must be hex, e.g. `63 ff 00 00`")
        }
        guard report == 1 || report == 2 else { throw ValidationError("--report must be 1 or 2") }
    }

    func run() throws {
        let payload = bytes.compactMap { UInt8($0, radix: 16) }
        try options.withDevice { blink1 in
            guard read else { return try blink1.sendRaw(payload, reportID: report) }
            let response = try blink1.requestRaw(payload, reportID: report)
            Terminal.output(response.map { String(format: "%02x", $0) }.joined(separator: " "))
        }
    }
}
