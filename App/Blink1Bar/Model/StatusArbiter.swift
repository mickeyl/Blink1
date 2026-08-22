import Foundation
import Observation

/// Decides which source gets the LED.
///
/// The rule is deliberately dull: highest priority wins, and among equals the newest claim. Dullness
/// is the point — with several sources feeding one lamp, the outcome has to be predictable from the
/// claims alone, without knowing who happened to write last.
@Observable
final class StatusArbiter {

    private(set) var claims: [StatusClaim.Source: StatusClaim] = [:]

    /// The claim currently showing, ignoring the ones that have lapsed.
    var winner: StatusClaim? {
        claims.values
            .filter { !$0.hasExpired() }
            .max { left, right in
                left.priority == right.priority
                    ? left.claimedAt < right.claimedAt
                    : left.priority < right.priority
            }
    }

    /// The claim that would show if the winner went away — what the LED falls back to.
    var underlying: StatusClaim? {
        guard let winner else { return nil }
        return claims.values
            .filter { !$0.hasExpired() && $0.source != winner.source }
            .max { $0.priority < $1.priority }
    }

    func claim(_ claim: StatusClaim) {
        claims[claim.source] = claim
    }

    func withdraw(_ source: StatusClaim.Source) {
        claims.removeValue(forKey: source)
    }

    /// Drops every pushed claim, leaving only the ambient layer — what "off" and a bare "clear" mean.
    func withdrawAll() {
        claims = claims.filter { $0.key == .ambient }
    }

    /// Drops what has lapsed. Returns true when that changed anything, so the caller knows to
    /// re-apply rather than poll the device for no reason.
    @discardableResult
    func dropExpiredClaims() -> Bool {
        let expired = claims.filter { $0.value.hasExpired() }
        guard !expired.isEmpty else { return false }
        expired.keys.forEach { claims.removeValue(forKey: $0) }
        return true
    }

    /// When the next claim lapses, so the caller can wake up exactly then instead of polling.
    var nextExpiry: Date? {
        claims.values.compactMap(\.expiresAt).min()
    }
}
