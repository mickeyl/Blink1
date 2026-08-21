import Blink1
import Foundation

/// Turns the time of day into a color: indigo at night, warm at sunrise, bright at noon, amber
/// towards the evening. Decoration, not information — it is the mode to leave running.
enum TimeOfDayPalette {

    /// Keyframes in minutes since midnight, interpolated linearly in between.
    private static let stops: [(minutes: Int, color: Blink1.Color)] = [
        (0 * 60, Blink1.Color(red: 8, green: 0, blue: 40)),
        (5 * 60 + 30, Blink1.Color(red: 50, green: 12, blue: 60)),
        (7 * 60, Blink1.Color(red: 255, green: 90, blue: 20)),
        (9 * 60, Blink1.Color(red: 255, green: 170, blue: 90)),
        (12 * 60, Blink1.Color(red: 255, green: 235, blue: 200)),
        (17 * 60, Blink1.Color(red: 255, green: 180, blue: 110)),
        (19 * 60 + 30, Blink1.Color(red: 255, green: 80, blue: 20)),
        (21 * 60 + 30, Blink1.Color(red: 110, green: 20, blue: 70)),
        (23 * 60, Blink1.Color(red: 8, green: 0, blue: 40)),
        (24 * 60, Blink1.Color(red: 8, green: 0, blue: 40)),
    ]

    static func color(at date: Date = .now, calendar: Calendar = .current) -> Blink1.Color {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        guard let upperIndex = stops.firstIndex(where: { $0.minutes >= minutes }) else { return stops[0].color }
        guard upperIndex > 0 else { return stops[0].color }

        let lower = stops[upperIndex - 1]
        let upper = stops[upperIndex]
        let span = upper.minutes - lower.minutes
        let progress = span > 0 ? Double(minutes - lower.minutes) / Double(span) : 0
        return blend(lower.color, upper.color, progress)
    }

    /// A day's worth of colors, for the preview strip in the menu.
    static func preview(steps: Int = 24, calendar: Calendar = .current) -> [Blink1.Color] {
        (0..<steps).map { step in
            let minutes = step * (24 * 60) / steps
            var components = DateComponents()
            components.hour = minutes / 60
            components.minute = minutes % 60
            let date = calendar.date(from: components) ?? .now
            return color(at: date, calendar: calendar)
        }
    }

    private static func blend(_ from: Blink1.Color, _ to: Blink1.Color, _ progress: Double) -> Blink1.Color {
        func mix(_ a: UInt8, _ b: UInt8) -> UInt8 {
            UInt8((Double(a) + (Double(b) - Double(a)) * progress).rounded())
        }
        return Blink1.Color(red: mix(from.red, to.red),
                            green: mix(from.green, to.green),
                            blue: mix(from.blue, to.blue))
    }
}
