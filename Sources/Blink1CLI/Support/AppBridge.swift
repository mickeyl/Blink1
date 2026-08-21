import ArgumentParser
import Blink1Control

/// Routes a command to a running Blink1Bar instead of the device.
///
/// While the app runs it owns the blink(1): writing to the device behind its back would produce a
/// light that contradicts what the app believes it is showing, and the next time the app applies its
/// state the command would silently vanish.
enum AppBridge {

    enum Outcome {
        case handled(ControlResponse)
        case appNotRunning
        case failed(String)
    }

    static func forward(_ request: ControlRequest) -> Outcome {
        do {
            return .handled(try ControlClient.send(request))
        } catch ControlClient.Failure.notRunning {
            return .appNotRunning
        } catch {
            return .failed(error.description)
        }
    }
}

/// The escape hatch for the commands that would otherwise be routed through the app.
struct AppOptions: ParsableArguments {

    @Flag(name: .long, help: "Talk to the device directly, even while Blink1Bar is running.")
    var direct = false

    /// Returns true when the request was handled by the app and the caller is done.
    func forwarded(_ request: ControlRequest) throws -> Bool {
        guard !direct else { return false }
        switch AppBridge.forward(request) {
            case .handled(let response):
                guard response.ok else {
                    Terminal.failure(response.error ?? "Blink1Bar refused the request")
                    throw ExitCode(1)
                }
                Terminal.note("Blink1Bar: \(response.mode ?? "?")\(response.detail.map { " \($0)" } ?? "")")
                return true
            case .appNotRunning:
                return false
            case .failed(let message):
                Terminal.failure(message, hint: "Pass --direct to bypass Blink1Bar.")
                throw ExitCode(1)
        }
    }
}
