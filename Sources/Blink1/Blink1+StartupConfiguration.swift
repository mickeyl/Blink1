import Foundation

extension Blink1 {

    /// What the device does the moment it receives USB power, stored in flash.
    public struct StartupConfiguration: Sendable, Hashable, CustomStringConvertible {

        public enum Mode: UInt8, Sendable, Hashable, CaseIterable, CustomStringConvertible {

            /// Firmware default: play the stored pattern from position 0.
            case normal = 0
            /// Play the configured sub-range.
            case play = 1
            /// Stay dark until told otherwise.
            case off = 2

            public var description: String {
                switch self {
                    case .normal: "normal"
                    case .play: "play"
                    case .off: "off"
                }
            }
        }

        public var mode: Mode
        public var startPosition: UInt8
        public var endPosition: UInt8
        /// 0 means repeat forever.
        public var repeats: UInt8

        public init(mode: Mode, startPosition: UInt8 = 0, endPosition: UInt8 = 0, repeats: UInt8 = 0) {
            self.mode = mode
            self.startPosition = startPosition
            self.endPosition = endPosition
            self.repeats = repeats
        }

        public var description: String {
            "\(mode), pattern \(startPosition)…\(endPosition), \(repeats == 0 ? "endless" : "\(repeats)×")"
        }
    }
}
