import SwiftUI

/// The two knobs behind the audio meter, and the switch that works them for you.
struct AudioSettingsView: View {

    @Environment(AppModel.self) private var model

    @State private var floorDecibels: Double = -50
    @State private var expansion: Double = 2.5

    var body: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $model.preferences.audioAutoAdjusts) {
                Text(R.L.Audio_AUTOMATIC)
            }
            .toggleStyle(.checkbox)
            .help(R.L.Audio_AUTOMATIC_HELP)

            HStack {
                Text(R.L.Audio_SENSITIVITY)
                Slider(value: $floorDecibels, in: -70 ... -25) { editing in
                    guard !editing else { return }
                    // Touching a slider means taking over.
                    model.preferences.audioAutoAdjusts = false
                    model.preferences.audioFloorDecibels = floorDecibels
                }
                Text(verbatim: "\(Int(floorDecibels)) dB")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }

            HStack {
                Text(R.L.Audio_DYNAMICS)
                Slider(value: $expansion, in: 1...6) { editing in
                    guard !editing else { return }
                    model.preferences.audioAutoAdjusts = false
                    model.preferences.audioExpansion = expansion
                }
                Text(verbatim: String(format: "%.1f×", expansion))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
            .help(R.L.Audio_DYNAMICS_HELP)
        }
        .font(.callout)
        .onAppear { readSettings() }
        // While the tuner has the wheel, the sliders follow it rather than sit there lying.
        .onChange(of: model.audioMeter.effectiveFloorDecibels) { _, _ in readSettings() }
        .onChange(of: model.audioMeter.effectiveExpansion) { _, _ in readSettings() }
    }

    private func readSettings() {
        floorDecibels = model.audioMeter.effectiveFloorDecibels
        expansion = model.audioMeter.effectiveExpansion
    }
}
