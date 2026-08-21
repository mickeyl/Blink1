import ArgumentParser
import Blink1
import Blink1Control

struct StatusCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Ask Blink1Bar what it is showing.",
        discussion: "Falls back to reading the device directly when the app is not running.")

    @Flag(name: .long, help: "Emit JSON.")
    var json = false

    @OptionGroup var options: DeviceOptions

    func run() throws {
        switch AppBridge.forward(.status) {
            case .handled(let response):
                guard !json else { return try Terminal.printJSON(response) }
                Terminal.output("\(response.mode ?? "?")\(response.detail.map { " \($0)" } ?? "")")
                if let device = response.device { Terminal.note("device \(device)") }

            case .failed(let message):
                Terminal.failure(message)
                throw ExitCode(1)

            case .appNotRunning:
                Terminal.note("Blink1Bar is not running — reading the device instead")
                try options.withDevice { blink1 in
                    let color = try blink1.readColor().color
                    let state = try blink1.readPlayState()
                    let response = ControlResponse(ok: true,
                                                   mode: state.isPlaying ? "pattern" : "color",
                                                   detail: state.isPlaying
                                                       ? "\(state.startPosition)…\(state.endPosition)"
                                                       : color.hexString,
                                                   device: blink1.serialNumber)
                    guard !json else { return try Terminal.printJSON(response) }
                    Terminal.output("\(response.mode ?? "?")\(response.detail.map { " \($0)" } ?? "")")
                }
        }
    }
}
