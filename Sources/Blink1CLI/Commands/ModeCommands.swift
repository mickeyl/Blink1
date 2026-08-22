import ArgumentParser
import Blink1Control

struct AudioCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "audio",
        abstract: "Let the LEDs follow the system audio.",
        discussion: "The top LED shows the left channel, the bottom one the right. Needs the app — "
            + "it holds the audio tap, the device only gets colors.")

    @OptionGroup var output: OutputOptions

    func run() throws {
        output.apply()
        try ModeCommand.hand(over: .audio, named: "audio")
    }
}

struct ClearCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "clear",
        abstract: "Withdraw a pushed status, back to what the app was showing.",
        discussion: "The counterpart to `signal`: it takes the status away and lets the mode chosen "
            + "in the menu — clock, audio, a color — have the LED back.")

    @Option(name: .long, help: ArgumentHelp("Which claim to withdraw.", valueName: "name"))
    var source: String?

    @OptionGroup var output: OutputOptions

    func run() throws {
        output.apply()
        try ModeCommand.hand(over: .clear(source: source), named: "cleared")
    }
}

struct ClockCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "clock",
        abstract: "Hand the LED back to Blink1Bar's clock.",
        discussion: "The counterpart to `signal` and `set`: it releases a status and lets the color "
            + "follow the time of day again. Needs the app — the clock lives there, not in the device.")

    @OptionGroup var output: OutputOptions

    func run() throws {
        output.apply()
        try ModeCommand.hand(over: .clock, named: "clock")
    }
}

/// Shared by the modes that only the app can serve.
enum ModeCommand {

    static func hand(over request: ControlRequest, named name: String) throws {
        switch AppBridge.forward(request) {
            case .handled(let response):
                guard response.ok else {
                    Terminal.failure(response.error ?? "Blink1Bar refused the request")
                    throw ExitCode(1)
                }
                Terminal.note("Blink1Bar: \(name)\(response.detail.map { " \($0)" } ?? "")")
            case .appNotRunning:
                Terminal.failure("Blink1Bar is not running",
                                 hint: "This mode lives in the app; start it with `make app-run`.")
                throw ExitCode(2)
            case .failed(let message):
                Terminal.failure(message)
                throw ExitCode(1)
        }
    }
}
