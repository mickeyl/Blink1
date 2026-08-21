import Blink1
import SwiftUI

/// Plays one of the signals stored in the device's bank — the same vocabulary status sources will
/// use later, here driven by hand.
struct SignalSectionView: View {

    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 6)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Blink1.Signal.allCases, id: \.self) { signal in
                Button {
                    model.preferences.signal = signal
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(DeviceOutput.signal(signal).indicatorColor.swiftUI)
                            .frame(width: 8, height: 8)
                            .overlay { Circle().strokeBorder(.secondary.opacity(0.4)) }
                        Text(signal.localizedName)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(signal == model.preferences.signal ? Color.accentColor.opacity(0.25) : .clear)
                    }
                }
                .buttonStyle(.plain)
                .help(signal.summary)
            }
        }
        .font(.callout)
    }
}

extension Blink1.Signal {

    var localizedName: String {
        switch self {
            case .off: R.L.Signal_OFF
            case .ok: R.L.Signal_OK
            case .idle: R.L.Signal_IDLE
            case .busy: R.L.Signal_BUSY
            case .info: R.L.Signal_INFO
            case .warn: R.L.Signal_WARN
            case .error: R.L.Signal_ERROR
            case .critical: R.L.Signal_CRITICAL
            case .success: R.L.Signal_SUCCESS
            case .failure: R.L.Signal_FAILURE
            case .hostGone: R.L.Signal_HOST_GONE
        }
    }
}
