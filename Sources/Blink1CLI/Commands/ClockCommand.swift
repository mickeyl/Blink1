import ArgumentParser
import Blink1Control

struct ClockCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "clock",
        abstract: "Hand the LED back to Blink1Bar's clock.",
        discussion: "The counterpart to `signal` and `set`: it releases a status and lets the color "
            + "follow the time of day again. Needs the app — the clock lives there, not in the device.")

    @OptionGroup var output: OutputOptions

    func run() throws {
        output.apply()
        switch AppBridge.forward(.clock) {
            case .handled(let response):
                guard response.ok else {
                    Terminal.failure(response.error ?? "Blink1Bar refused the request")
                    throw ExitCode(1)
                }
                Terminal.note("Blink1Bar: clock\(response.detail.map { " \($0)" } ?? "")")
            case .appNotRunning:
                Terminal.failure("Blink1Bar is not running", hint: "The clock lives in the app; start it with `make app-run`.")
                throw ExitCode(2)
            case .failed(let message):
                Terminal.failure(message)
                throw ExitCode(1)
        }
    }
}
