import AppKit
import Blink1
import SwiftUI

/// The status item itself: a dot in the color the LED currently shows.
///
/// Menu bar labels are rendered as template images, which would throw the color away — hence the
/// hand-drawn `NSImage` with `isTemplate` off. Unplug the device and the same dot comes back struck
/// through, as a template symbol that follows the menu bar's own appearance.
struct MenuBarLabel: View {

    let color: Blink1.Color
    let isConnected: Bool

    var body: some View {
        if isConnected {
            Image(nsImage: Self.dot(for: color))
        } else {
            Image(systemName: "circle.slash")
        }
    }

    private static func dot(for color: Blink1.Color) -> NSImage {
        let size = NSSize(width: 15, height: 15)
        let image = NSImage(size: size, flipped: false) { rect in
            let inset = rect.insetBy(dx: 2.5, dy: 2.5)
            NSColor(srgbRed: Double(color.red) / 255,
                    green: Double(color.green) / 255,
                    blue: Double(color.blue) / 255,
                    alpha: 1).setFill()
            NSBezierPath(ovalIn: inset).fill()
            // A faint ring keeps a dark or black dot visible against the menu bar.
            NSColor.labelColor.withAlphaComponent(0.55).setStroke()
            let ring = NSBezierPath(ovalIn: inset.insetBy(dx: 0.5, dy: 0.5))
            ring.lineWidth = 1
            ring.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }
}
