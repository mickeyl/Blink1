import ArgumentParser
import Blink1

struct InfoCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Show what the device is and what it can do.")

    @OptionGroup var options: DeviceOptions

    @Flag(name: .long, help: "Emit JSON instead of a table.")
    var json = false

    func run() throws {
        try options.withDevice { blink1 in
            let report = try Report(blink1)
            guard !json else { return try Terminal.printJSON(report) }
            Terminal.output("serial          \(report.serialNumber)")
            Terminal.output("model           \(report.model)")
            Terminal.output("product         \(report.productName)")
            Terminal.output("firmware        \(report.firmware)")
            Terminal.output("leds            \(report.ledCount)")
            Terminal.output("pattern slots   \(report.patternSlots)")
            Terminal.output("gamma           \(report.gammaCorrection)")
            if let startup = report.startup { Terminal.output("startup         \(startup)") }
            if let chipID = report.chipID { Terminal.output("chip id         \(chipID)") }
        }
    }

    struct Report: Encodable {

        let serialNumber: String
        let model: String
        let productName: String
        let firmware: String
        let ledCount: Int
        let patternSlots: Int
        let gammaCorrection: String
        let startup: String?
        let chipID: String?

        init(_ blink1: Blink1) throws {
            self.serialNumber = blink1.serialNumber
            self.model = blink1.model.description
            self.productName = blink1.info.productName
            self.firmware = try blink1.firmwareVersionString()
            self.ledCount = blink1.model.ledCount
            self.patternSlots = blink1.patternSlots
            self.gammaCorrection = blink1.model.correctsGammaInFirmware ? "in firmware" : "on host"
            // Both are firmware/model dependent; a device that says no is not an error here.
            self.startup = try? blink1.startupConfiguration().description
            self.chipID = blink1.model.supportsNotes ? try? blink1.chipID() : nil
        }
    }
}
