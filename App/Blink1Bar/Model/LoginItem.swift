import Foundation
import ServiceManagement

/// Registers the app with launchd so it comes back after a reboot.
///
/// `SMAppService` keeps the state itself — there is nothing to store in the preferences, and asking
/// it is the only way to learn what the user did in System Settings.
enum LoginItem {

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// True once the user has denied the registration in System Settings; the toggle then needs the
    /// detour through Login Items rather than another attempt.
    static var requiresApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
