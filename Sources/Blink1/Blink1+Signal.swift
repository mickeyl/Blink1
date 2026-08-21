import Foundation

extension Blink1 {

    /// A status signal, stored as a fixed range of the device's 32 pattern slots.
    ///
    /// The layout is deliberately static: once the bank is installed, switching status is a single
    /// "play slots x…y" command instead of rewriting pattern lines, and the device keeps signalling
    /// on its own — through host sleep, a crashed daemon, or a logout.
    ///
    /// Signals are told apart by **rhythm** first and color second. Two small LEDs seen from the
    /// corner of the eye carry motion far better than hue, and red/green alone excludes a good part
    /// of any audience.
    public enum Signal: String, Sendable, Hashable, Codable, CaseIterable, CustomStringConvertible {

        /// Dark. Nothing to report, and nothing to look at.
        case off
        /// Steady green. Everything is fine.
        case ok
        /// Very dim teal, breathing slowly. Powered and watching, nothing going on.
        case idle
        /// Blue, breathing at a working pace. Something is running.
        case busy
        /// A short cyan blip every second. Something wants to be read, but nothing is wrong.
        case info
        /// Amber double pulse. Needs a look, not a rescue.
        case warn
        /// Fast red double blink. Something broke.
        case error
        /// Red and white strobe. Drop everything.
        case critical
        /// Two green flashes, then steady green. Plays once and stays — a finished job that went well.
        case success
        /// Two red flashes, then steady red. Plays once and stays — a finished job that did not.
        case failure
        /// Slow, dim red heartbeat. Nobody has talked to the device in a while; the watchdog fires this.
        case hostGone = "host-gone"

        public var description: String { rawValue }

        /// Where this signal lives in the device's pattern memory. The ranges are contiguous and
        /// together cover all 32 slots.
        public var slots: ClosedRange<UInt8> {
            switch self {
                // Slot 0 belongs to a multi-slot signal on purpose: an end position of 0 means
                // "play everything" to the firmware, so a lone slot 0 could never be played.
                case .idle: 0...1
                case .ok: 2...2
                case .off: 3...3
                case .busy: 4...5
                case .info: 6...7
                case .warn: 8...11
                case .error: 12...15
                case .critical: 16...17
                case .success: 18...22
                case .failure: 23...27
                case .hostGone: 28...31
            }
        }

        /// How often the device repeats the range; 0 plays it forever.
        ///
        /// `success` and `failure` run once and hold their last step, which is why their last step is
        /// a steady color rather than darkness.
        public var repeats: UInt8 {
            switch self {
                case .success, .failure: 1
                default: 0
            }
        }

        /// One line per slot, scaled by `brightness` (0…1).
        ///
        /// A step's fade time is also how long it lasts — there is no separate hold — so a flash is a
        /// short fade to the color followed by a short fade away from it.
        public func steps(brightness: Double = 1) -> [PatternLine] {
            let bank: [(Color, Duration)] = switch self {
                case .off:
                    [(.black, .milliseconds(200))]
                case .ok:
                    [(Color(red: 0, green: 210, blue: 60), .milliseconds(500))]
                case .idle:
                    [(Color(red: 0, green: 45, blue: 35), .milliseconds(1_800)),
                     (Color(red: 0, green: 6, blue: 5), .milliseconds(1_800))]
                case .busy:
                    [(Color(red: 0, green: 70, blue: 255), .milliseconds(700)),
                     (Color(red: 0, green: 10, blue: 45), .milliseconds(700))]
                case .info:
                    [(Color(red: 0, green: 190, blue: 255), .milliseconds(120)),
                     (Color(red: 0, green: 8, blue: 12), .milliseconds(900))]
                case .warn:
                    [(Color(red: 255, green: 130, blue: 0), .milliseconds(150)),
                     (Color(red: 30, green: 12, blue: 0), .milliseconds(150)),
                     (Color(red: 255, green: 130, blue: 0), .milliseconds(150)),
                     (Color(red: 30, green: 12, blue: 0), .milliseconds(900))]
                case .error:
                    [(Color(red: 255, green: 25, blue: 0), .milliseconds(90)),
                     (.black, .milliseconds(90)),
                     (Color(red: 255, green: 25, blue: 0), .milliseconds(90)),
                     (.black, .milliseconds(600))]
                case .critical:
                    [(Color(red: 255, green: 0, blue: 0), .milliseconds(60)),
                     (.white, .milliseconds(60))]
                case .success:
                    [(Color(red: 0, green: 230, blue: 70), .milliseconds(80)),
                     (.black, .milliseconds(80)),
                     (Color(red: 0, green: 230, blue: 70), .milliseconds(80)),
                     (.black, .milliseconds(80)),
                     (Color(red: 0, green: 210, blue: 60), .milliseconds(900))]
                case .failure:
                    [(Color(red: 255, green: 30, blue: 0), .milliseconds(80)),
                     (.black, .milliseconds(80)),
                     (Color(red: 255, green: 30, blue: 0), .milliseconds(80)),
                     (.black, .milliseconds(80)),
                     (Color(red: 200, green: 0, blue: 0), .milliseconds(900))]
                case .hostGone:
                    [(Color(red: 90, green: 0, blue: 0), .milliseconds(800)),
                     (.black, .milliseconds(800)),
                     (Color(red: 90, green: 0, blue: 0), .milliseconds(800)),
                     (.black, .milliseconds(2_000))]
            }
            return bank.map { PatternLine(color: $0.0.dimmed(to: brightness), fadeDuration: $0.1) }
        }

        /// How the signal reads at a glance, for help texts and menus.
        public var summary: String {
            switch self {
                case .off: "dark"
                case .ok: "steady green"
                case .idle: "dim teal, breathing slowly"
                case .busy: "blue, breathing"
                case .info: "short cyan blip every second"
                case .warn: "amber double pulse"
                case .error: "fast red double blink"
                case .critical: "red and white strobe"
                case .success: "two green flashes, then steady green"
                case .failure: "two red flashes, then steady red"
                case .hostGone: "slow dim red heartbeat"
            }
        }

        /// Slots the whole bank occupies — a device needs at least this many.
        public static let requiredSlots = 32
    }
}
