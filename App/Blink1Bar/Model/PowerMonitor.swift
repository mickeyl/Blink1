import AppKit
import Foundation

/// Watches the machine going to sleep and coming back.
///
/// Waking matters more than it looks: the blink(1) may have been re-enumerated while the Mac slept,
/// which makes the open device handle useless — the app has to reconnect and re-assert its state
/// rather than assume the LED still shows what it was told hours ago.
@MainActor
final class PowerMonitor {

    private var observers: [NSObjectProtocol] = []

    func start(onSleep: @escaping @MainActor () -> Void, onWake: @escaping @MainActor () -> Void) {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification,
                                           object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { onSleep() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification,
                                           object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { onWake() }
        })
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }
}
