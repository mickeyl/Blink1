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
            SegmentedMeterChannel(label: meter.channelLabels.left,
                                  level: meter.currentLevels.left,
                                  meter: meter)
            SegmentedMeterChannel(label: meter.channelLabels.right,
                                  level: meter.currentLevels.right,
                                  meter: meter)

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
}

/// A fixed-colour meter: its ramp stays put while the level only switches segments on and off.
private struct SegmentedMeterChannel: View {

    private static let segmentCount = 24

    let label: String
    let level: Float
    let meter: any LiveMeter

    private var clampedLevel: Float {
        min(max(level, 0), 1)
    }

    private var activeSegmentCount: Int {
        Int((clampedLevel * Float(Self.segmentCount)).rounded(.up))
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)

            HStack(spacing: 2) {
                ForEach(0..<Self.segmentCount, id: \.self) { segment in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(meter.color(for: Float(segment + 1) / Float(Self.segmentCount)).swiftUI)
                        .opacity(segment < activeSegmentCount ? 1 : 0.12)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityValue(Text(Double(clampedLevel), format: .percent.precision(.fractionLength(0))))
    }
}
