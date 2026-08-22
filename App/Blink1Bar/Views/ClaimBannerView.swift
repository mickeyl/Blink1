import Blink1
import SwiftUI

/// Shows who took the LED away from the mode picked in the menu, and hands it back.
///
/// Without this the menu would quietly lie: the picker still points at Clock while a script's error
/// is on the device.
struct ClaimBannerView: View {

    @Environment(AppModel.self) private var model

    let claim: StatusClaim

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(claim.presentation.output.indicatorColor.swiftUI)
                .frame(width: 8, height: 8)
                .overlay { Circle().strokeBorder(.secondary.opacity(0.4)) }

            VStack(alignment: .leading, spacing: 1) {
                Text(headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button(R.L.Claim_RELEASE) { model.withdrawClaim(from: claim.source) }
                .buttonStyle(.link)
        }
        .font(.callout)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.6)))
    }

    private var headline: String {
        if let label = claim.label { return label }
        return switch claim.presentation {
            case .signal(let signal): signal.localizedName
            case .color(let color): color.hexString
            case .audio: R.L.MenuContent_MODE_AUDIO
            case .off: R.L.MenuContent_MODE_OFF
        }
    }

    private var subtitle: String {
        guard let expiresAt = claim.expiresAt else { return R.L.Claim_HELD_BY(claim.source.rawValue) }
        return R.L.Claim_HELD_UNTIL(claim.source.rawValue, max(Int(expiresAt.timeIntervalSinceNow), 0))
    }
}
