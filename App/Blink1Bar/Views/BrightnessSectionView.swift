import SwiftUI

/// Brightness plus the night-time reduction that applies to every mode.
struct BrightnessSectionView: View {

    @Environment(AppModel.self) private var model

    /// The slider drives the device while dragging; the value is only stored when it comes to rest.
    @State private var brightness: Double = 0

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(R.L.MenuContent_BRIGHTNESS)
                Spacer()
                Text(brightness.formatted(.percent.precision(.fractionLength(0))))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.callout)

            Slider(value: $brightness, in: 0.02...1) { editing in
                guard !editing else { return }
                model.commitBrightness(brightness)
            }
            .onChange(of: brightness) { _, value in model.previewBrightness(value) }

            Toggle(isOn: $model.preferences.dimsAtNight) {
                Text(R.L.MenuContent_DIM_AT_NIGHT)
            }
            .font(.callout)
            .toggleStyle(.checkbox)

            if model.preferences.dimsAtNight {
                HStack(spacing: 6) {
                    hourPicker(selection: $model.preferences.nightStartHour)
                    Text("–").foregroundStyle(.secondary)
                    hourPicker(selection: $model.preferences.nightEndHour)
                    Spacer()
                }
                .font(.callout)
            }
        }
        .onAppear { brightness = model.preferences.brightness }
    }

    private func hourPicker(selection: Binding<Int>) -> some View {
        Picker(selection: selection) {
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour)).tag(hour)
            }
        } label: {
            EmptyView()
        }
        .labelsHidden()
        .frame(width: 82)
    }
}
