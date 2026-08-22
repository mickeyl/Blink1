import Blink1
import Foundation

/// A source that paints the two LEDs frame by frame rather than setting a colour once.
///
/// Audio, system load and network throughput are the same shape of thing: two channels, a level
/// each, updated continuously. Only the rate and where the numbers come from differ, so the loop
/// that drives them lives in one place and this is what it talks to.
@MainActor
protocol LiveMeter: AnyObject {

    /// Opens whatever the meter needs — a tap, a counter, a first sample.
    func start() throws
    func stop()

    /// How often the device gets a new frame. A blink(1) needs 6ms for a stereo frame and its fade
    /// engine ticks every 10ms, so there is no point going far beyond thirty.
    var frameRate: Double { get }
    /// How long the device takes to reach the new colour; it interpolates the gap between frames.
    var fadeDuration: Duration { get }

    /// The next pair of levels, 0…1 each, or nil while the meter has nothing to say.
    func levels(elapsed: TimeInterval) -> (left: Float, right: Float)?
    /// The last pair measured — for the menu, which must not drive the measurement itself.
    var currentLevels: (left: Float, right: Float) { get }
    /// How this meter colours a level. Different ramps keep the meters apart at a glance.
    func color(for level: Float) -> Blink1.Color

    /// Shown in the menu while this meter is running.
    var channelLabels: (left: String, right: String) { get }
}

/// Which continuous meter has the LEDs.
enum LiveMeterKind: String, Codable, CaseIterable, Identifiable, Sendable {

    case audio
    case systemLoad
    case network

    var id: String { rawValue }
}

nonisolated extension Blink1.Color {

    /// The gradient every VU meter uses: dark green, green, yellow, orange, red.
    ///
    /// The colour carries the level, not the brightness — a bar graph lights its segments at full
    /// intensity and lets the hue do the talking, which is what makes the top of the scale read as
    /// "hot" at a glance. Only the bottom of the range fades out, so silence is dark rather than a
    /// permanent green glow.
    private static let vuRamp: [(level: Double, color: (r: Double, g: Double, b: Double))] = [
        (0.00, (0, 40, 8)),
        (0.20, (0, 150, 20)),
        (0.42, (40, 255, 0)),
        (0.62, (200, 255, 0)),
        (0.75, (255, 210, 0)),
        (0.88, (255, 110, 0)),
        (1.00, (255, 0, 0)),
    ]

    /// Cool where the VU ramp is warm, so a glance tells the meters apart without reading the menu.
    private static let flowRamp: [(level: Double, color: (r: Double, g: Double, b: Double))] = [
        (0.00, (0, 10, 40)),
        (0.25, (0, 60, 200)),
        (0.55, (0, 180, 255)),
        (0.80, (120, 240, 255)),
        (1.00, (255, 255, 255)),
    ]

    init(meterLevel level: Float) {
        self.init(level: level, ramp: Self.vuRamp)
    }

    init(flowLevel level: Float) {
        self.init(level: level, ramp: Self.flowRamp)
    }

    private init(level: Float, ramp: [(level: Double, color: (r: Double, g: Double, b: Double))]) {
        let level = Double(min(max(level, 0), 1))
        guard level > 0.005 else { self = .black; return }

        var color = ramp[0].color
        for (index, stop) in ramp.enumerated() where level >= stop.level {
            guard index + 1 < ramp.count else { color = stop.color; break }
            let next = ramp[index + 1]
            let progress = (level - stop.level) / (next.level - stop.level)
            color = (stop.color.r + (next.color.r - stop.color.r) * progress,
                     stop.color.g + (next.color.g - stop.color.g) * progress,
                     stop.color.b + (next.color.b - stop.color.b) * progress)
        }

        // Fade in over the quietest tenth so nothing to report goes dark instead of glowing.
        let fadeIn = min(level / 0.1, 1)
        self.init(red: UInt8((color.r * fadeIn).rounded()),
                  green: UInt8((color.g * fadeIn).rounded()),
                  blue: UInt8((color.b * fadeIn).rounded()))
    }
}
