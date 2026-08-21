import ArgumentParser
import Blink1
import Blink1Control

struct SignalCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "signal",
        abstract: "Show a status signal from the installed bank.",
        discussion: "One command, no pattern writing: the device plays the signal by itself and keeps "
            + "going after this process exits. Run `blink1 bank install` once beforehand.")

    @Argument(help: ArgumentHelp("Which signal to show.", valueName: "signal"))
    var signal: SignalArgument

    @OptionGroup var app: AppOptions
    @OptionGroup var options: DeviceOptions

    func run() throws {
        guard try !app.forwarded(.signal(signal.signal.rawValue)) else { return }
        try options.withDevice { blink1 in
            try blink1.show(signal.signal)
            Terminal.note("\(signal.signal) — \(signal.signal.summary)")
        }
    }
}

struct SignalArgument: ExpressibleByArgument {

    let signal: Blink1.Signal

    init?(argument: String) {
        guard let signal = Blink1.Signal(rawValue: argument.lowercased()) else { return nil }
        self.signal = signal
    }

    static var allValueStrings: [String] { Blink1.Signal.allCases.map(\.rawValue) }

    var defaultValueDescription: String { signal.rawValue }
}
