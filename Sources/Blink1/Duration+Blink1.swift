import Foundation

extension Duration {

    /// The protocol encodes all timings as a 16-bit count of 10ms ticks, so ~10.9 minutes is the ceiling.
    public static let blink1Maximum = Duration.milliseconds(0xFFFF * 10)

    public var blink1Milliseconds: Int {
        let (seconds, attoseconds) = self.components
        return Int(seconds) * 1_000 + Int(attoseconds / 1_000_000_000_000_000)
    }

    /// Rounds towards zero and clamps into the encodable range, matching the reference implementation.
    public var blink1Ticks: UInt16 { UInt16(min(max(blink1Milliseconds / 10, 0), 0xFFFF)) }

    public init(blink1Ticks: UInt16) { self = .milliseconds(Int(blink1Ticks) * 10) }
}
