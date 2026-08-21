import Blink1
import SwiftUI

/// Decoration mode: one steady color, picked by hand.
struct StaticColorSectionView: View {

    @Environment(AppModel.self) private var model

    private static let presets: [Blink1.Color] = [
        .init(red: 255, green: 140, blue: 40),
        .init(red: 255, green: 60, blue: 90),
        .init(red: 190, green: 60, blue: 255),
        .init(red: 60, green: 110, blue: 255),
        .init(red: 0, green: 200, blue: 190),
        .init(red: 80, green: 220, blue: 60),
        .init(red: 255, green: 220, blue: 130),
        .white,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ColorPicker(R.L.Color_PICKER, selection: colorSelection, supportsOpacity: false)
                .font(.callout)

            HStack(spacing: 6) {
                ForEach(Self.presets, id: \.self) { preset in
                    Button {
                        model.preferences.staticColor = preset
                    } label: {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(preset.swiftUI)
                            .frame(height: 22)
                            .overlay {
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(preset == model.preferences.staticColor ? Color.primary : .clear,
                                                  lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                    .help(preset.hexString)
                }
            }
        }
    }

    private var colorSelection: Binding<Color> {
        Binding(get: { model.preferences.staticColor.swiftUI },
                set: { model.preferences.staticColor = Blink1.Color($0) })
    }
}
