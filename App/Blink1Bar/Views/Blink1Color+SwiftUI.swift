import Blink1
import SwiftUI

extension Blink1.Color {

    var swiftUI: Color {
        Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    init(_ color: Color) {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(red: UInt8((resolved.redComponent * 255).rounded()),
                  green: UInt8((resolved.greenComponent * 255).rounded()),
                  blue: UInt8((resolved.blueComponent * 255).rounded()))
    }
}
