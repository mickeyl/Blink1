import Blink1
import Blink1Control
import Foundation

extension AppModel {

    /// Answers one request from the CLI, a script or — later — a status source.
    ///
    /// Requests land in the same preferences the menu edits, so whatever a script sets is visible in
    /// the UI and survives a restart. Once sources with priorities arrive, this is where they queue
    /// up instead of writing through.
    func handle(_ request: ControlRequest) -> ControlResponse {
        switch request {
            case .status:
                break
            case .off:
                preferences.mode = .off
            case .clock:
                preferences.mode = .timeOfDay
            case .audio:
                preferences.mode = .audio
            case .signal(let name):
                guard let signal = Blink1.Signal(rawValue: name.lowercased()) else {
                    return .failure("unknown signal '\(name)' — try \(Blink1.Signal.allCases.map(\.rawValue).joined(separator: ", "))")
                }
                preferences.signal = signal
                preferences.mode = .signal
            case .color(let text):
                guard let color = Blink1.Color(text) else {
                    return .failure("'\(text)' is not a color — try a name, #rrggbb or r,g,b")
                }
                preferences.staticColor = color
                preferences.mode = .color
        }
        return status()
    }

    private func status() -> ControlResponse {
        let mode: String
        let detail: String?
        switch preferences.mode {
            case .off:
                mode = "off"
                detail = nil
            case .color:
                mode = "color"
                detail = preferences.staticColor.hexString
            case .signal:
                mode = "signal"
                detail = preferences.signal.rawValue
            case .timeOfDay:
                mode = "clock"
                detail = timeOfDayColor.hexString
            case .audio:
                mode = "audio"
                detail = String(format: "L %.0f%% R %.0f%%", audioLevels.left * 100, audioLevels.right * 100)
        }
        return ControlResponse(ok: true, mode: mode, detail: detail, device: connection?.serialNumber)
    }
}
