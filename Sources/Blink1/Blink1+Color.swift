import Foundation

extension Blink1 {

    /// An 8-bit-per-channel RGB color, the only thing a blink(1) understands.
    public struct Color: Sendable, Hashable, Codable, CustomStringConvertible {

        public var red: UInt8
        public var green: UInt8
        public var blue: UInt8

        public init(red: UInt8, green: UInt8, blue: UInt8) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        /// Accepts `#rgb`, `#rrggbb`, `rgb`, `rrggbb`, and `r,g,b` with decimal components.
        public init?(_ string: String) {
            let text = string.trimmingCharacters(in: .whitespaces).lowercased()
            if text.contains(",") {
                let components = text.split(separator: ",").compactMap { UInt8($0.trimmingCharacters(in: .whitespaces)) }
                guard components.count == 3 else { return nil }
                self.init(red: components[0], green: components[1], blue: components[2])
                return
            }
            if let named = Self.named[text] {
                self = named
                return
            }
            let digits = text.hasPrefix("#") ? String(text.dropFirst()) : text
            guard digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16) else { return nil }
            switch digits.count {
                case 3:
                    let r = UInt8((value >> 8) & 0xF), g = UInt8((value >> 4) & 0xF), b = UInt8(value & 0xF)
                    self.init(red: r << 4 | r, green: g << 4 | g, blue: b << 4 | b)
                case 6:
                    self.init(red: UInt8((value >> 16) & 0xFF), green: UInt8((value >> 8) & 0xFF), blue: UInt8(value & 0xFF))
                default:
                    return nil
            }
        }

        /// - Parameters:
        ///   - hue: 0…1, where 0 is red, 1/3 green, 2/3 blue.
        ///   - saturation: 0…1
        ///   - brightness: 0…1
        public init(hue: Double, saturation: Double, brightness: Double) {
            let h = (hue - hue.rounded(.down)) * 6
            let s = min(max(saturation, 0), 1)
            let v = min(max(brightness, 0), 1)
            let sector = Int(h)
            let f = h - Double(sector)
            let p = v * (1 - s)
            let q = v * (1 - s * f)
            let t = v * (1 - s * (1 - f))
            let (r, g, b) = switch sector {
                case 0: (v, t, p)
                case 1: (q, v, p)
                case 2: (p, v, t)
                case 3: (p, q, v)
                case 4: (t, p, v)
                default: (v, p, q)
            }
            self.init(red: UInt8((r * 255).rounded()), green: UInt8((g * 255).rounded()), blue: UInt8((b * 255).rounded()))
        }

        public var hexString: String { String(format: "#%02x%02x%02x", red, green, blue) }

        public var description: String { hexString }

        public var isBlack: Bool { red == 0 && green == 0 && blue == 0 }

        /// Linearly scales all components. `factor` is clamped to 0…1.
        public func dimmed(to factor: Double) -> Color {
            let f = min(max(factor, 0), 1)
            return Color(red: UInt8((Double(red) * f).rounded()),
                         green: UInt8((Double(green) * f).rounded()),
                         blue: UInt8((Double(blue) * f).rounded()))
        }

        public static func random() -> Color {
            Color(red: .random(in: 0...255), green: .random(in: 0...255), blue: .random(in: 0...255))
        }

        public static let black = Color(red: 0, green: 0, blue: 0)
        public static let white = Color(red: 255, green: 255, blue: 255)
        public static let red = Color(red: 255, green: 0, blue: 0)
        public static let green = Color(red: 0, green: 255, blue: 0)
        public static let blue = Color(red: 0, green: 0, blue: 255)
        public static let yellow = Color(red: 255, green: 255, blue: 0)
        public static let cyan = Color(red: 0, green: 255, blue: 255)
        public static let magenta = Color(red: 255, green: 0, blue: 255)
        public static let orange = Color(red: 255, green: 90, blue: 0)
        public static let amber = Color(red: 255, green: 160, blue: 0)
        public static let purple = Color(red: 140, green: 0, blue: 255)
        public static let pink = Color(red: 255, green: 60, blue: 130)
        public static let teal = Color(red: 0, green: 200, blue: 160)
        public static let lime = Color(red: 160, green: 255, blue: 0)

        /// Colors addressable by name, e.g. on a command line.
        public static let named: [String: Color] = [
            "black": .black, "off": .black, "white": .white, "red": .red, "green": .green,
            "blue": .blue, "yellow": .yellow, "cyan": .cyan, "magenta": .magenta,
            "orange": .orange, "amber": .amber, "purple": .purple, "pink": .pink,
            "teal": .teal, "lime": .lime,
        ]
    }
}
