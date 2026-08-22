import Blink1
import SwiftUI

/// The LEDs follow the system audio: top LED is the left channel, bottom the right.
struct AudioSectionView: View {

    @Environment(AppModel.self) private var model

    @State private var floorDecibels: Double = -50

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = model.audioErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            meter(channel: "L", level: model.audioLevels.left)
            meter(channel: "R", level: model.audioLevels.right)
            scale

            Text(R.L.Audio_EXPLANATION)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(R.L.Audio_SENSITIVITY)
                Slider(value: $floorDecibels, in: -70 ... -25) { editing in
                    guard !editing else { return }
                    model.preferences.audioFloorDecibels = floorDecibels
                }
                Text(verbatim: "\(Int(floorDecibels)) dB")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
            .font(.callout)
        }
        .onAppear { floorDecibels = model.preferences.audioFloorDecibels }
    }

    /// The ramp the LEDs run through, drawn from the very function that feeds them.
    private var scale: some View {
        HStack(spacing: 0) {
            ForEach(0..<60, id: \.self) { step in
                Rectangle().fill(Blink1.Color(audioLevel: Float(step) / 59).swiftUI)
            }
        }
        .frame(height: 5)
        .clipShape(RoundedRectangle(cornerRadius: 2.5))
        .padding(.leading, 16)
    }

    /// The bar carries the same color the LED shows, so the menu reads like the device.
    private func meter(channel: String, level: Float) -> some View {
        HStack(spacing: 6) {
            Text(channel)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 10)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(Blink1.Color(audioLevel: level).swiftUI)
                        .frame(width: max(geometry.size.width * Double(level), 2))
                }
            }
            .frame(height: 8)
        }
    }
}
