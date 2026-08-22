import Foundation

extension Bundle {

    /// The app's marketing version, e.g. "0.1.0". Empty when running outside a bundle.
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
