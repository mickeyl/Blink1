import AppKit
import Blink1
import SwiftUI

/// The whole UI: one panel that hangs off the status item.
struct MenuContentView: View {

    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 12) {
            DeviceStatusView()

            Picker(selection: $model.preferences.mode) {
                Text(R.L.MenuContent_MODE_OFF).tag(Preferences.Mode.off)
                Text(R.L.MenuContent_MODE_COLOR).tag(Preferences.Mode.color)
                Text(R.L.MenuContent_MODE_SIGNAL).tag(Preferences.Mode.signal)
                Text(R.L.MenuContent_MODE_TIME).tag(Preferences.Mode.timeOfDay)
                Text(R.L.MenuContent_MODE_AUDIO).tag(Preferences.Mode.audio)
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch model.preferences.mode {
                case .off: EmptyView()
                case .color: StaticColorSectionView()
                case .signal: SignalSectionView()
                case .timeOfDay: TimeOfDaySectionView()
                case .audio: AudioSectionView()
            }

            Divider()

            BrightnessSectionView()

            Divider()

            GeneralSectionView()

            Divider()

            HStack {
                Button(R.L.MenuContent_REINSTALL_BANK) { model.reinstallBank() }
                    .disabled(!model.isConnected)
                Spacer()
                Button(R.L.MenuContent_QUIT) {
                    Task {
                        await model.prepareForTermination()
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
            .buttonStyle(.link)
            .font(.callout)
        }
        .padding(14)
        .frame(width: 300)
    }
}
