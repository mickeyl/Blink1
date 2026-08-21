import ArgumentParser
import Blink1

struct ListCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List the attached blink(1) devices.",
        discussion: "The index printed here is what `--device` accepts, next to the serial number.")

    @Flag(name: .long, help: "Emit JSON instead of a table.")
    var json = false

    @Flag(name: .long, help: "Never colorize output.")
    var noColor = false

    func run() throws {
        Terminal.colorSuppressed = noColor
        let devices = Blink1.discover()

        guard !json else { return try Terminal.printJSON(devices) }
        guard !devices.isEmpty else {
            Terminal.failure("no blink(1) found", hint: "Plug one in — `system_profiler SPUSBDataType` shows what macOS sees.")
            throw ExitCode(2)
        }
        for (index, info) in devices.enumerated() {
            let columns = ["\(index)", info.serialNumber, info.model.description, info.productName]
            Terminal.output(Terminal.isOutputTTY
                ? "\(columns[0])  \(columns[1])  \(columns[2].padding(toLength: 7, withPad: " ", startingAt: 0))\(columns[3])"
                : columns.joined(separator: "\t"))
        }
    }
}
