import Blink1
import SwiftUI

/// Which device is being driven, and whether it is there at all.
struct DeviceStatusView: View {

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let connection = model.connection {
                HStack(alignment: .firstTextBaseline) {
                    Text(connection.productName)
                        .font(.headline)
                    Spacer(minLength: 8)
                    appVersion
                }
                Text(R.L.Device_DETAILS(connection.serialNumber, connection.firmware))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Label(model.lastErrorMessage ?? R.L.Device_NONE_ATTACHED, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    appVersion
                }
            }

            if model.attachedDevices.count > 1 {
                Picker(R.L.Device_PICKER, selection: deviceSelection) {
                    Text(R.L.Device_AUTOMATIC).tag(String?.none)
                    ForEach(model.attachedDevices, id: \.serialNumber) { device in
                        Text(device.serialNumber).tag(String?.some(device.serialNumber))
                    }
                }
                .font(.callout)
            }
        }
    }

    /// Trailing on the first line, quiet enough not to compete with the device it sits next to.
    private var appVersion: some View {
        Text(verbatim: "v\(Bundle.main.shortVersion)")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .monospacedDigit()
    }

    private var deviceSelection: Binding<String?> {
        Binding(get: { model.preferences.preferredSerialNumber },
                set: { model.selectDevice(serialNumber: $0) })
    }
}
