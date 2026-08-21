import Foundation

extension Blink1 {

    /// Snapshot of the on-device pattern player.
    public struct PlayState: Sendable, Hashable, CustomStringConvertible {

        public var isPlaying: Bool
        public var startPosition: UInt8
        public var endPosition: UInt8
        /// Repeats left to play, 0 when looping forever.
        public var remainingRepeats: UInt8
        /// Only meaningful while playing — mk3 firmware leaves stale data in this byte once stopped.
        public var currentPosition: UInt8

        public var description: String {
            isPlaying
                ? "playing \(startPosition)…\(endPosition) at \(currentPosition), \(remainingRepeats == 0 ? "endless" : "\(remainingRepeats) left")"
                : "stopped"
        }
    }
}
