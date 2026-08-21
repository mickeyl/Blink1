import Foundation

extension Blink1 {

    /// Which of the two LEDs (mk2 and later) a command addresses.
    public enum LED: UInt8, Sendable, Hashable, CaseIterable, CustomStringConvertible {

        case all = 0
        case top = 1
        case bottom = 2

        public var description: String {
            switch self {
                case .all: "all"
                case .top: "top"
                case .bottom: "bottom"
            }
        }
    }
}
