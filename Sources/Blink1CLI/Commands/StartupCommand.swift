import ArgumentParser
import Blink1

struct StartupCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "startup",
        abstract: "Configure what the device does when it gets power.",
        discussion: "Requires firmware 2.06 or later. The setting lives in flash and survives unplugging.",
        subcommands: [Show.self, Set.self],
        defaultSubcommand: Show.self)

    struct Show: ParsableCommand {

        static let configuration = CommandConfiguration(commandName: "show", abstract: "Print the power-on behaviour.")

        @Flag(name: .long, help: "Emit JSON.")
        var json = false

        @OptionGroup var options: DeviceOptions

        func run() throws {
            try options.withDevice { blink1 in
                let configuration = try blink1.startupConfiguration()
                guard !json else {
                    return try Terminal.printJSON(Snapshot(mode: configuration.mode.description,
                                                           start: configuration.startPosition,
                                                           end: configuration.endPosition,
                                                           repeats: configuration.repeats))
                }
                Terminal.output(configuration.description)
            }
        }

        struct Snapshot: Encodable {
            let mode: String
            let start: UInt8
            let end: UInt8
            let repeats: UInt8
        }
    }

    struct Set: ParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Store the power-on behaviour in flash.")

        @Option(name: [.customShort("m"), .long], help: "normal, play or off.")
        var mode: StartupModeArgument

        @Option(name: [.customShort("s"), .long], help: "First pattern slot to play.")
        var start: UInt8 = 0

        @Option(name: [.customShort("e"), .long], help: "Last pattern slot to play.")
        var end: UInt8 = 0

        @Option(name: [.customShort("r"), .long], help: "How often to repeat; 0 plays forever.")
        var repeats: UInt8 = 0

        @OptionGroup var options: DeviceOptions

        func run() throws {
            try options.withDevice { blink1 in
                let configuration = Blink1.StartupConfiguration(mode: mode.mode, startPosition: start,
                                                                endPosition: end, repeats: repeats)
                try blink1.setStartupConfiguration(configuration)
                Terminal.note("startup: \(configuration)")
            }
        }
    }
}
