import AppKit

/// Presents independently of the menu content, which SwiftUI creates only after its first click.
@MainActor
enum PhysicalResetAlert {

    static func present(serialNumber: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = R.L.Device_RESET_TITLE
        alert.informativeText = R.L.Device_RESET_MESSAGE(serialNumber)
        alert.addButton(withTitle: R.L.Device_RESET_BUTTON)
        NSApp.activate()
        alert.runModal()
    }
}
