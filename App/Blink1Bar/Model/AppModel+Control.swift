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
                // "off" means off, so everything pushed in steps aside too.
                withdrawAllClaims()
                preferences.mode = .off
            case .clear(let source):
                // Naming a source clears that one; clearing without a name clears the lot, which is
                // what someone typing `blink1 clear` after a script died actually wants.
                if let source {
                    withdrawClaim(from: .init(rawValue: source))
                } else {
                    withdrawAllClaims()
                }
            case .clock:
                preferences.mode = .timeOfDay
            case .audio:
                preferences.mode = .audio
            case .signal(let name, let seconds, let source):
                guard let signal = Blink1.Signal(rawValue: name.lowercased()) else {
                    return .failure("unknown signal '\(name)' — try \(Blink1.Signal.allCases.map(\.rawValue).joined(separator: ", "))")
                }
                claim(.signal(signal),
                      priority: signal.claimPriority,
                      from: source.map { StatusClaim.Source(rawValue: $0) } ?? .external,
                      for: seconds.map { .milliseconds(Int($0 * 1000)) })
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
        if let claim = externalClaim, case .signal(let signal) = claim.presentation {
            let remaining = claim.expiresAt.map { ", \(max(Int($0.timeIntervalSinceNow), 0))s left" } ?? ""
            return ControlResponse(ok: true, mode: "signal",
                                   detail: "\(signal) (\(claim.source)\(remaining))",
                                   device: connection?.serialNumber)
        }
        return ambientStatus()
    }

    private func ambientStatus() -> ControlResponse {
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
