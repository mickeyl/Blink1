import Blink1
import SwiftUI

/// The clock drives the color: indigo at night, warm at sunrise, bright at noon, amber in the evening.
struct TimeOfDaySectionView: View {

    @Environment(AppModel.self) private var model

    private static let previewColors = TimeOfDayPalette.preview(steps: 48)

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 1) {
                ForEach(Array(Self.previewColors.enumerated()), id: \.offset) { _, color in
                    Rectangle().fill(color.swiftUI)
                }
            }
            .frame(height: 16)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(alignment: .leading) { marker }

            Text(R.L.Time_EXPLANATION)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle(R.L.Time_BLIP_ON_THE_HOUR, isOn: $model.preferences.blipOnTheHour)
                .font(.callout)
                .toggleStyle(.checkbox)
        }
    }

    /// Where in the day we are, drawn on top of the strip.
    private var marker: some View {
        GeometryReader { geometry in
            let minutes = Calendar.current.component(.hour, from: .now) * 60
                + Calendar.current.component(.minute, from: .now)
            Rectangle()
                .fill(.white)
                .frame(width: 2)
                .shadow(radius: 1)
                .offset(x: geometry.size.width * Double(minutes) / (24 * 60))
        }
    }
}
