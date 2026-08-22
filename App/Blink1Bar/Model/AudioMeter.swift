import Blink1
import CoreAudio
import Foundation
import Observation

/// The stereo VU meter: system audio in, two channel levels out.
///
/// Holds the three pieces that make the picture readable — the tap, the envelope that keeps it from
/// twitching, and the tuner that reads the material and sets the two knobs itself.
@Observable
@MainActor
final class AudioMeter: LiveMeter {

    /// Where the scale bottoms out and how far it spreads, as currently in force. With the tuner on
    /// these follow the material; otherwise they are what the sliders say.
    private(set) var effectiveFloorDecibels: Double = -50
    private(set) var effectiveExpansion: Double = 2.5
    private(set) var levels: (left: Float, right: Float) = (0, 0)

    var currentLevels: (left: Float, right: Float) { levels }
    /// Set when the tap could not be opened — most likely a denied permission.
    private(set) var errorMessage: String?

    var manualFloorDecibels: Double = -50
    var manualExpansion: Double = 2.5
    var adjustsAutomatically = true

    private let tap = SystemAudioTap()
    private var envelope = AudioLevelMeter()
    private var tuner = AudioAutoTuner()
    private var target: AudioAutoTuner.Settings?

    /// The aggregate device behind the tap, so the on-air lamp can tell it from a real microphone.
    var deviceID: AudioObjectID? { tap.deviceID }

    nonisolated var frameRate: Double { 30 }
    nonisolated var fadeDuration: Duration { .milliseconds(40) }
    nonisolated var channelLabels: (left: String, right: String) { ("L", "R") }

    func start() throws {
        do {
            try tap.start()
            errorMessage = nil
        } catch {
            errorMessage = error.description
            throw error
        }
    }

    func stop() {
        tap.stop()
        envelope.reset()
        tuner.reset()
        target = nil
        levels = (0, 0)
    }

    func levels(elapsed: TimeInterval) -> (left: Float, right: Float)? {
        let raw = tap.currentLevels
        tune(with: raw, elapsed: elapsed)
        envelope.floorDecibels = Float(effectiveFloorDecibels)
        envelope.expansion = Float(effectiveExpansion)
        levels = envelope.update(with: raw, elapsed: elapsed)
        return levels
    }

    nonisolated func color(for level: Float) -> Blink1.Color {
        Blink1.Color(meterLevel: level)
    }

    /// Keeps the two settings current: straight from the sliders by hand, or ramped towards what the
    /// tuner read off the material. Ramped rather than set, because a proposal every twenty seconds
    /// would otherwise be a visible jolt.
    private func tune(with raw: SystemAudioTap.Levels, elapsed: TimeInterval) {
        guard adjustsAutomatically else {
            effectiveFloorDecibels = manualFloorDecibels
            effectiveExpansion = manualExpansion
            target = nil
            return
        }

        tuner.record(left: raw.left, right: raw.right)
        if let proposal = tuner.proposal() {
            target = proposal
        }
        guard let target else { return }

        let step = min(elapsed / 3, 1)
        effectiveFloorDecibels += (Double(target.floorDecibels) - effectiveFloorDecibels) * step
        effectiveExpansion += (Double(target.expansion) - effectiveExpansion) * step
    }
}
