import SwiftUI

/// The knobs that are not about color: autostart, what happens during sleep, and whether the device
/// should complain on its own when the app stops talking to it.
struct GeneralSectionView: View {

    @Environment(AppModel.self) private var model

    @State private var startsAtLogin = false

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $startsAtLogin) {
                Text(R.L.MenuContent_START_AT_LOGIN)
            }
            .toggleStyle(.checkbox)
            .onChange(of: startsAtLogin) { _, enabled in
                model.setStartsAtLogin(enabled)
                startsAtLogin = model.startsAtLogin
            }

            if LoginItem.requiresApproval {
                Button(R.L.MenuContent_LOGIN_APPROVAL) { LoginItem.openSystemSettings() }
                    .buttonStyle(.link)
                    .font(.caption)
            }

            Toggle(isOn: $model.preferences.armsWatchdog) {
                Text(R.L.MenuContent_WATCHDOG)
            }
            .toggleStyle(.checkbox)
            .help(R.L.MenuContent_WATCHDOG_HELP)

            HStack {
                Text(R.L.MenuContent_SLEEP)
                Picker(selection: $model.preferences.sleepBehavior) {
                    Text(R.L.Sleep_OFF).tag(Preferences.SleepBehavior.off)
                    Text(R.L.Sleep_KEEP).tag(Preferences.SleepBehavior.keep)
                } label: {
                    EmptyView()
                }
                .labelsHidden()
                .frame(width: 130)
            }
        }
        .font(.callout)
        .onAppear { startsAtLogin = model.startsAtLogin }
    }
}
