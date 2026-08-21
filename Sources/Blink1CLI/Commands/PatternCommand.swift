import ArgumentParser
import Blink1

struct PatternCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "pattern",
        abstract: "Work with the color pattern stored inside the device.",
        discussion: "A pattern is a list of color/fade steps the device plays on its own — the "
            + "way to signal continuously without keeping a process running. Writes land in RAM; "
            + "`pattern save` makes them survive a power cycle.",
        subcommands: [Show.self, Set.self, Save.self, Play.self, Stop.self, State.self, Clear.self],
        defaultSubcommand: Show.self)

    struct Show: ParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Print the pattern currently in the device.")

        @Flag(name: .long, help: "Emit JSON instead of a table.")
        var json = false

        @OptionGroup var options: DeviceOptions

        func run() throws {
            try options.withDevice { blink1 in
                let lines = try blink1.readPattern()
                let entries = lines.enumerated().map { index, line in
                    Entry(position: index, color: line.color.hexString,
                          fadeMilliseconds: line.fadeDuration.blink1Milliseconds, led: line.led.description)
                }
                guard !json else { return try Terminal.printJSON(entries) }
                for entry in entries {
                    let color = Blink1.Color(entry.color) ?? .black
                    Terminal.output(Terminal.isOutputTTY
                        ? String(format: "%2d  ", entry.position) + Terminal.swatch(color)
                          + "\(entry.color)  \(entry.fadeMilliseconds)ms  \(entry.led)"
                        : "\(entry.position)\t\(entry.color)\t\(entry.fadeMilliseconds)\t\(entry.led)")
                }
            }
        }

        struct Entry: Encodable {
            let position: Int
            let color: String
            let fadeMilliseconds: Int
            let led: String
        }
    }

    struct Set: ParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Write one pattern line (into RAM — use `pattern save` to persist).")

        @Argument(help: "Slot to write.")
        var position: UInt8

        @Argument(help: ArgumentHelp("The color for this step.", valueName: "color"))
        var color: Blink1.Color

        @Option(name: [.customShort("f"), .long], help: "Fade time for this step, e.g. 300ms.")
        var fade: TimeSpan = TimeSpan(.milliseconds(300))

        @Option(name: [.customShort("l"), .long], help: "Which LED this step addresses: all, top, bottom.")
        var led: LEDArgument = LEDArgument(.all)

        @OptionGroup var options: DeviceOptions

        func run() throws {
            try options.withDevice { blink1 in
                let line = Blink1.PatternLine(color: color, fadeDuration: fade.duration, led: led.led)
                try blink1.writePatternLine(line, at: position)
                Terminal.note("slot \(position): \(Terminal.swatch(color))\(line) — not saved yet, run `blink1 pattern save`")
            }
        }
    }

    struct Save: ParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "save",
            abstract: "Persist the pattern to the device's flash memory.")

        @OptionGroup var options: DeviceOptions

        func run() throws {
            try options.withDevice { blink1 in
                try blink1.savePattern()
                Terminal.note("pattern written to flash")
            }
        }
    }

    struct Play: ParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "play",
            abstract: "Let the device play its stored pattern.")

        @Option(name: [.customShort("s"), .long], help: "First slot to play.")
        var start: UInt8 = 0

        @Option(name: [.customShort("e"), .long], help: "Last slot to play, inclusive; defaults to the last one.")
        var end: UInt8?

        @Option(name: [.customShort("r"), .long], help: "How often to repeat; 0 plays forever.")
        var repeats: UInt8 = 0

        @OptionGroup var options: DeviceOptions

        func run() throws {
            try options.withDevice { blink1 in
                let last = end ?? UInt8(blink1.patternSlots - 1)
                guard start <= last else { throw ValidationError("--start must not be past --end") }
                try blink1.play(start...last, repeats: repeats)
                Terminal.note("playing \(start)…\(last)\(repeats == 0 ? " endlessly" : " \(repeats)×")")
            }
        }
    }

    struct Stop: ParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "stop",
            abstract: "Stop pattern playback, leaving the current color lit.")

        @OptionGroup var options: DeviceOptions

        func run() throws {
            try options.withDevice { blink1 in
                try blink1.stop()
                Terminal.note("stopped")
            }
        }
    }

    struct State: ParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "state",
            abstract: "Show what the pattern player is doing.")

        @Flag(name: .long, help: "Emit JSON.")
        var json = false

        @OptionGroup var options: DeviceOptions

        func run() throws {
            try options.withDevice { blink1 in
                let state = try blink1.readPlayState()
                guard !json else {
                    return try Terminal.printJSON(Snapshot(playing: state.isPlaying,
                                                           start: state.startPosition,
                                                           end: state.endPosition,
                                                           position: state.currentPosition,
                                                           remainingRepeats: state.remainingRepeats))
                }
                Terminal.output(state.description)
            }
        }

        struct Snapshot: Encodable {
            let playing: Bool
            let start: UInt8
            let end: UInt8
            let position: UInt8
            let remainingRepeats: UInt8
        }
    }

    struct Clear: ParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "clear",
            abstract: "Overwrite every pattern slot with black.")

        @Flag(name: [.customShort("f"), .long], help: "Skip the confirmation prompt.")
        var force = false

        @Flag(name: .long, help: "Also write the cleared pattern to flash.")
        var save = false

        @OptionGroup var options: DeviceOptions

        func run() throws {
            try options.withDevice { blink1 in
                let scope = save ? "in RAM and flash" : "in RAM"
                guard force || Terminal.confirm("Clear all \(blink1.patternSlots) pattern slots \(scope)?") else {
                    Terminal.failure("aborted", hint: "Pass --force to clear without asking.")
                    throw ExitCode(1)
                }
                let empty = Blink1.PatternLine(color: .black, fadeDuration: .zero)
                for position in 0..<UInt8(blink1.patternSlots) {
                    try blink1.writePatternLine(empty, at: position)
                }
                if save { try blink1.savePattern() }
                Terminal.note("cleared \(blink1.patternSlots) slots \(scope)")
            }
        }
    }
}
