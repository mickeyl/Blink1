import ArgumentParser
import Blink1
import Blink1Control

struct SignalCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "signal",
        abstract: "Show a status signal from the installed bank.",
        discussion: "One command, no pattern writing: the device plays the signal by itself and keeps "
            + "going after this process exits. Run `blink1 bank install` once beforehand.\n\n"
            + "While Blink1Bar runs, a signal outranks whatever it was showing and stays until "
            + "`blink1 clear`, something more urgent arrives, or --duration runs out.")

    @Argument(help: ArgumentHelp("Which signal to show.", valueName: "signal"))
    var signal: SignalArgument

    @Option(name: .long, help: "Withdraw the signal again after this long, e.g. 30s. Needs Blink1Bar.")
    var duration: TimeSpan?

    @Option(name: .long, help: ArgumentHelp("Name this claim, so several scripts can hold one each.",
                                            valueName: "name"))
    var source: String?

    @OptionGroup var app: AppOptions
    @OptionGroup var options: DeviceOptions

    func run() throws {
        let seconds = duration.map { Double($0.duration.blink1Milliseconds) / 1000 }
        guard try !app.forwarded(.signal(signal.signal.rawValue, seconds: seconds, source: source)) else { return }
        if seconds != nil {
            Terminal.note("--duration needs Blink1Bar; without it the device just keeps showing the signal")
        }
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
