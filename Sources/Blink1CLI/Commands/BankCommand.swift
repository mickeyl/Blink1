import ArgumentParser
import Blink1

struct BankCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "bank",
        abstract: "Manage the 32-slot signal bank inside the device.",
        discussion: "The bank puts every status signal into the device's pattern memory once, so "
            + "`blink1 signal <name>` becomes a single command and the device keeps signalling "
            + "without a process running.",
        subcommands: [Install.self, Map.self, Watchdog.self, Startup.self],
        defaultSubcommand: Map.self)

    struct Install: ParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "install",
            abstract: "Write all signals into the device.",
            discussion: "Without --save the bank lives in RAM and unplugging brings back whatever was "
                + "in flash. With --save it replaces the stored pattern for good — the previous "
                + "contents cannot be read back, so there is no undo.")

        @Option(name: [.customShort("b"), .long], help: "Scale every color, 0.0 to 1.0.")
        var brightness: Double = 1.0

        @Flag(name: .long, help: "Also write the bank to flash, surviving a power cycle.")
        var save = false

        @Flag(name: [.customShort("f"), .long], help: "Skip the confirmation prompt for --save.")
        var force = false

        @OptionGroup var options: DeviceOptions

        func validate() throws {
            guard (0...1).contains(brightness) else { throw ValidationError("brightness must be between 0.0 and 1.0") }
        }

        func run() throws {
            try options.withDevice { blink1 in
                if save, !force,
                   !Terminal.confirm("Replace the pattern stored in \(blink1.serialNumber)'s flash? This cannot be undone.") {
                    Terminal.failure("aborted", hint: "Leave out --save to install into RAM only.")
                    throw ExitCode(1)
                }
                try blink1.installSignals(brightness: brightness, persist: save)
                Terminal.note("installed \(Blink1.Signal.allCases.count) signals in "
                    + "\(Blink1.Signal.requiredSlots) slots\(save ? ", written to flash" : " (RAM only)")")
            }
        }
    }

    struct Map: ParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "map",
            abstract: "Print the slot layout and what each signal looks like.")

        @Flag(name: .long, help: "Emit JSON.")
        var json = false

        @Flag(name: .long, help: "Never colorize output.")
        var noColor = false

        func run() throws {
            Terminal.colorSuppressed = noColor
            let entries = Blink1.Signal.allCases.sorted { $0.slots.lowerBound < $1.slots.lowerBound }.map { signal in
                Entry(signal: signal.rawValue,
                      firstSlot: signal.slots.lowerBound,
                      lastSlot: signal.slots.upperBound,
                      steps: signal.slots.count,
                      repeats: signal.repeats,
                      summary: signal.summary)
            }
            guard !json else { return try Terminal.printJSON(entries) }
            for entry in entries {
                let range = entry.firstSlot == entry.lastSlot
                    ? "\(entry.firstSlot)"
                    : "\(entry.firstSlot)…\(entry.lastSlot)"
                Terminal.output(Terminal.isOutputTTY
                    ? "\(entry.signal.padding(toLength: 11, withPad: " ", startingAt: 0))"
                      + "\(range.padding(toLength: 8, withPad: " ", startingAt: 0))"
                      + "\(entry.repeats == 0 ? "loop " : "once ") \(entry.summary)"
                    : "\(entry.signal)\t\(entry.firstSlot)\t\(entry.lastSlot)\t\(entry.repeats)\t\(entry.summary)")
            }
        }

        struct Entry: Encodable {
            let signal: String
            let firstSlot: UInt8
            let lastSlot: UInt8
            let steps: Int
            let repeats: UInt8
            let summary: String
        }
    }

    struct Watchdog: ParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "watchdog",
            abstract: "Arm the watchdog so it falls back to a signal.",
            discussion: "Re-run this from a heartbeat to keep it quiet — no other command counts as a "
                + "sign of life. The current color is kept until the watchdog fires.")

        @Option(name: [.customShort("t"), .long], help: "Fire after this much silence, e.g. 30s.")
        var timeout: TimeSpan

        @Option(name: [.customShort("s"), .long], help: "Signal to show when it fires.")
        var signal: SignalArgument = SignalArgument(argument: "host-gone")!

        @OptionGroup var options: DeviceOptions

        func run() throws {
            try options.withDevice { blink1 in
                try blink1.armWatchdog(timeout: timeout.duration, showing: signal.signal)
                Terminal.note("watchdog armed: \(signal.signal) after "
                    + "\(timeout.duration.blink1Milliseconds)ms of silence")
            }
        }
    }

    struct Startup: ParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "startup",
            abstract: "Choose the signal the device shows when it gets power.",
            discussion: "Stored in flash, so it works before any software runs — including on a machine "
                + "that is still booting.")

        @Argument(help: ArgumentHelp("Signal to show at power-on.", valueName: "signal"))
        var signal: SignalArgument

        @OptionGroup var options: DeviceOptions

        func run() throws {
            try options.withDevice { blink1 in
                try blink1.setStartupSignal(signal.signal)
                Terminal.note("power-on signal: \(signal.signal)")
            }
        }
    }
}
