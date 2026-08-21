import ArgumentParser
import Blink1

struct BlinkCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "blink",
        abstract: "Blink a color a number of times.",
        discussion: "Runs on the host and blocks until finished, so it is meant for short "
            + "signals. For long or endless signalling store a pattern and let the device play it: "
            + "`blink1 pattern set …` followed by `blink1 pattern play`.")

    @Argument(help: ArgumentHelp("The color to blink.", valueName: "color"))
    var color: Blink1.Color

    @Option(name: [.customShort("c"), .long], help: "How often to blink.")
    var count: Int = 3

    @Option(name: [.customShort("p"), .long], help: "Duration of one on/off cycle, e.g. 400ms.")
    var period: TimeSpan = TimeSpan(.milliseconds(400))

    @OptionGroup var options: DeviceOptions

    func validate() throws {
        guard count > 0 else { throw ValidationError("count must be at least 1") }
        guard period.duration > .zero else { throw ValidationError("period must be greater than zero") }
    }

    func run() throws {
        try options.withDevice { blink1 in
            Terminal.note("\(Terminal.swatch(color))blinking \(color.hexString) \(count)×")
            try blink1.blink(color, times: count, period: period.duration)
        }
    }
}
