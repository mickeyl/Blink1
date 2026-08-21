import ArgumentParser
import Blink1

struct SelfTestCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "selftest",
        abstract: "Round-trip a report to check that the device answers.")

    @OptionGroup var options: DeviceOptions

    func run() throws {
        try options.withDevice { blink1 in
            let response = try blink1.selfTest()
            Terminal.output(response.map { String(format: "%02x", $0) }.joined(separator: " "))
            Terminal.note("\(blink1.serialNumber) (\(blink1.model)) answered")
        }
    }
}
