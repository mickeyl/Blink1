import Blink1
import Foundation

/// What a source wants the LED to show, and how badly.
///
/// Sources do not drive the device. They put in a claim and the arbiter decides — which is the only
/// way several of them can coexist without the last writer winning by accident.
struct StatusClaim: Identifiable, Equatable {

    /// Who is asking. One claim per source: a new one replaces the old.
    let source: Source
    let priority: Priority
    let presentation: Presentation
    let claimedAt: Date
    /// When the claim lapses on its own; nil means it stands until withdrawn.
    let expiresAt: Date?

    var id: Source { source }

    init(source: Source,
         priority: Priority,
         presentation: Presentation,
         claimedAt: Date = .now,
         duration: Duration? = nil) {
        self.source = source
        self.priority = priority
        self.presentation = presentation
        self.claimedAt = claimedAt
        self.expiresAt = duration.map { claimedAt.addingTimeInterval(Double($0.blink1Milliseconds) / 1000) }
    }

    func hasExpired(at date: Date = .now) -> Bool {
        guard let expiresAt else { return false }
        return date >= expiresAt
    }

    /// Open on purpose: a build script, a hook and a monitor are three sources, and each should be
    /// able to hold its own claim without knowing about the others.
    struct Source: Hashable, Sendable, RawRepresentable, CustomStringConvertible {

        let rawValue: String

        init(rawValue: String) { self.rawValue = rawValue }

        /// The mode picked in the menu — the layer everything else is measured against.
        static let ambient = Source(rawValue: "ambient")
        /// Anything pushed in from outside that did not name itself.
        static let external = Source(rawValue: "external")

        var description: String { rawValue }
    }

    /// Ordered by how much a claim deserves to be seen. Gaps leave room to slot sources in between.
    enum Priority: Int, Comparable, Sendable {
        /// Decoration: the clock, a static color, the audio meter.
        case ambient = 0
        /// Continuous background information — system load, network throughput.
        case background = 10
        /// Something is running or finished: busy, ok, success, failure.
        case status = 20
        /// Wants to be noticed: errors, a live microphone.
        case attention = 30
        /// Everything else steps aside.
        case alert = 40

        static func < (lhs: Priority, rhs: Priority) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    enum Presentation: Equatable, Sendable {
        case off
        case color(Blink1.Color)
        case signal(Blink1.Signal)
        /// Colors are pushed frame by frame rather than set once.
        case audio

        var output: DeviceOutput {
            switch self {
                case .off: .off
                case .color(let color): .color(color)
                case .signal(let signal): .signal(signal)
                case .audio: .audio
            }
        }
    }
}

extension Blink1.Signal {

    /// How loudly a signal asks for the LED. Anything that means "broken" outranks the rest, and a
    /// `critical` outranks even that.
    var claimPriority: StatusClaim.Priority {
        switch self {
            case .critical: .alert
            case .error, .failure, .hostGone: .attention
            case .warn, .info, .busy, .ok, .success, .idle, .off: .status
        }
    }
}
