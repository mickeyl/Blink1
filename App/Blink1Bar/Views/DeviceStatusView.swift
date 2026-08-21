import Blink1
import SwiftUI

/// Which device is being driven, and whether it is there at all.
struct DeviceStatusView: View {

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let connection = model.connection {
                Text(connection.productName)
                    .font(.headline)
                Text(R.L.Device_DETAILS(connection.serialNumber, connection.firmware))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label(model.lastErrorMessage ?? R.L.Device_NONE_ATTACHED, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
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

    private var deviceSelection: Binding<String?> {
        Binding(get: { model.preferences.preferredSerialNumber },
                set: { model.selectDevice(serialNumber: $0) })
    }
}
