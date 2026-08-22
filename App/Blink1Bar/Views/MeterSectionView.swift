import Blink1
import SwiftUI

/// The continuous meters: system audio, machine load, network throughput.
///
/// One section for all three, because they are the same thing with different numbers behind them —
/// two channels, a level each. Only audio brings settings of its own.
struct MeterSectionView: View {

    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: 8) {
            Picker(selection: $model.preferences.meterKind) {
                Text(R.L.Meter_AUDIO).tag(LiveMeterKind.audio)
                Text(R.L.Meter_LOAD).tag(LiveMeterKind.systemLoad)
                Text(R.L.Meter_NETWORK).tag(LiveMeterKind.network)
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if let message = model.audioMeter.errorMessage, model.preferences.meterKind == .audio {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let meter = model.meter(for: model.preferences.meterKind)
            channel(label: meter.channelLabels.left, level: meter.currentLevels.left, meter: meter)
            channel(label: meter.channelLabels.right, level: meter.currentLevels.right, meter: meter)
            scale(for: meter)

            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.preferences.meterKind == .audio {
                AudioSettingsView()
            }
        }
    }

    private var explanation: String {
        switch model.preferences.meterKind {
            case .audio: R.L.Meter_AUDIO_EXPLANATION
            case .systemLoad: R.L.Meter_LOAD_EXPLANATION
            case .network: R.L.Meter_NETWORK_EXPLANATION(rate(model.networkMeter.rates.incoming),
                                                         rate(model.networkMeter.rates.outgoing))
        }
    }

    private func rate(_ bytesPerSecond: Double) -> String {
        ByteCountFormatStyle(style: .memory, allowedUnits: [.kb, .mb, .gb], spellsOutZero: false)
            .format(Int64(max(bytesPerSecond, 0))) + "/s"
    }

    /// The bar carries the same colour the LED shows, so the menu reads like the device.
    private func channel(label: String, level: Float, meter: any LiveMeter) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(meter.color(for: level).swiftUI)
                        .frame(width: max(geometry.size.width * Double(level), 2))
                }
            }
            .frame(height: 8)
        }
    }

    /// The ramp the LEDs run through, drawn from the very function that feeds them.
    private func scale(for meter: any LiveMeter) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<60, id: \.self) { step in
                Rectangle().fill(meter.color(for: Float(step) / 59).swiftUI)
            }
        }
        .frame(height: 5)
        .clipShape(RoundedRectangle(cornerRadius: 2.5))
        .padding(.leading, 34)
    }
}
