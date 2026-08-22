import Foundation

/// Watches what the source material actually does and proposes settings for it.
///
/// Sensitivity and dynamics are two knobs describing one thing: where the programme sits and how
/// much room it uses. Both are readable from the level distribution, so there is no reason to make
/// someone find them by hand for every kind of material.
///
/// Percentiles rather than minimum and maximum: a single silent gap or one clipped peak should not
/// define the scale for the next half minute.
struct AudioAutoTuner {

    /// How much history a proposal is based on. Long enough to cover a verse and a chorus.
    static let windowSeconds: TimeInterval = 30
    /// Two to three adjustments a minute — often enough to follow a change of material, rare enough
    /// that nobody watches the meter re-scale itself.
    static let interval: TimeInterval = 22

    struct Settings: Equatable {
        var floorDecibels: Float
        var expansion: Float
    }

    /// Below this a sample is digital silence and says nothing about the material.
    private static let silenceDecibels: Float = -75
    /// The share of the scale the everyday range should fill.
    private static let targetSpan: Float = 0.85

    private var samples: [Float] = []
    private var capacity: Int
    private var lastProposal = Date.distantPast

    init(frameRate: Double = 30) {
        capacity = Int(Self.windowSeconds * frameRate)
        samples.reserveCapacity(capacity)
    }

    mutating func record(left: Float, right: Float) {
        let rms = max(left, right)
        guard rms > 0 else { return }
        let decibels = 20 * log10(rms)
        guard decibels > Self.silenceDecibels else { return }

        samples.append(decibels)
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }

    mutating func reset() {
        samples.removeAll(keepingCapacity: true)
        lastProposal = .distantPast
    }

    /// A proposal, once enough material has gone by and the last one is old enough.
    mutating func proposal(at date: Date = .now) -> Settings? {
        guard date.timeIntervalSince(lastProposal) >= Self.interval else { return nil }
        // A third of the window: less than that and the proposal would be guesswork.
        guard samples.count >= capacity / 3 else { return nil }
        lastProposal = date

        let sorted = samples.sorted()
        let quiet = percentile(sorted, 0.10)
        let loud = percentile(sorted, 0.95)

        // Put the bottom of the scale just under the quiet end, so quiet passages read as quiet
        // rather than as nothing.
        let floor = min(max(quiet - 3, -70), -25)

        // What is left of the range after the floor moved decides how much to spread: material
        // squeezed into a few decibels gets the most, material that already breathes gets little.
        let span = (loud - floor) / -floor
        let expansion = min(max(Self.targetSpan / max(span, 0.05), 1), 6)

        return Settings(floorDecibels: floor, expansion: expansion)
    }

    private func percentile(_ sorted: [Float], _ fraction: Float) -> Float {
        guard !sorted.isEmpty else { return Self.silenceDecibels }
        let index = Int((Float(sorted.count - 1) * fraction).rounded())
        return sorted[index]
    }
}
