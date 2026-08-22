import Blink1
import Foundation

/// Turns raw RMS values into something an eye can read.
///
/// Two steps do the work. First a decibel scale, because linear RMS spends almost its whole range on
/// the loudest fraction of music and leaves everything else crawling near zero. Then an envelope
/// with a fast attack and a slow release — the VU meter behaviour: transients register, but the
/// display does not flicker on every drum hit.
struct AudioLevelMeter {

    /// Where the scale bottoms out. Quieter than this reads as silence.
    var floorDecibels: Float = -50

    private var attackSeconds: Float = 0.01
    private var releaseSeconds: Float = 0.25
    private var left: Float = 0
    private var right: Float = 0

    /// - Parameter elapsed: time since the last update, so the envelope is frame-rate independent.
    /// - Returns: both channels on a 0…1 scale.
    mutating func update(with levels: SystemAudioTap.Levels, elapsed: TimeInterval) -> (left: Float, right: Float) {
        left = follow(left, target: normalized(levels.left), elapsed: Float(elapsed))
        right = follow(right, target: normalized(levels.right), elapsed: Float(elapsed))
        return (left, right)
    }

    mutating func reset() {
        left = 0
        right = 0
    }

    private func normalized(_ rms: Float) -> Float {
        guard rms > 0 else { return 0 }
        let decibels = 20 * log10(rms)
        return min(max((decibels - floorDecibels) / -floorDecibels, 0), 1)
    }

    private func follow(_ current: Float, target: Float, elapsed: Float) -> Float {
        let timeConstant = target > current ? attackSeconds : releaseSeconds
        // Exponential approach, so the same time constant holds at any frame rate.
        let coefficient = 1 - exp(-elapsed / timeConstant)
        return current + (target - current) * coefficient
    }
}

extension Blink1.Color {

    /// The gradient every VU meter uses: dark green, green, yellow, orange, red.
    ///
    /// The color carries the level, not the brightness — a bar graph lights its segments at full
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

    init(audioLevel level: Float) {
        let level = Double(min(max(level, 0), 1))
        guard level > 0.005 else { self = .black; return }

        var color = Self.vuRamp[0].color
        for (index, stop) in Self.vuRamp.enumerated() where level >= stop.level {
            guard index + 1 < Self.vuRamp.count else { color = stop.color; break }
            let next = Self.vuRamp[index + 1]
            let progress = (level - stop.level) / (next.level - stop.level)
            color = (stop.color.r + (next.color.r - stop.color.r) * progress,
                     stop.color.g + (next.color.g - stop.color.g) * progress,
                     stop.color.b + (next.color.b - stop.color.b) * progress)
        }

        // Fade in over the quietest tenth so silence goes dark instead of glowing.
        let fadeIn = min(level / 0.1, 1)
        self.init(red: UInt8((color.r * fadeIn).rounded()),
                  green: UInt8((color.g * fadeIn).rounded()),
                  blue: UInt8((color.b * fadeIn).rounded()))
    }
}
