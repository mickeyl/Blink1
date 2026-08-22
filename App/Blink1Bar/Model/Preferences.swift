import Blink1
import Foundation

/// Everything the user configures, stored as one JSON blob in `UserDefaults`.
///
/// One value rather than a dozen defaults keys: the app applies the whole state at once anyway, and
/// adding a knob later does not need a migration.
struct Preferences: Codable, Equatable, Sendable {

    enum Mode: String, Codable, CaseIterable, Identifiable, Sendable {
        case off
        case color
        case signal
        case timeOfDay
        case audio

        var id: String { rawValue }
    }

    /// What the LED does while the Mac sleeps. Keeping the last state would make it lie: nothing is
    /// watching any more, so by default it goes dark.
    enum SleepBehavior: String, Codable, CaseIterable, Identifiable, Sendable {
        case off
        case keep

        var id: String { rawValue }
    }

    var mode: Mode = .timeOfDay
    var brightness: Double = 0.6
    var staticColor: Blink1.Color = .init(red: 255, green: 140, blue: 40)
    var signal: Blink1.Signal = .ok
    /// A short blip on every full hour while the clock drives the LED.
    var blipOnTheHour: Bool = true
    /// Where the audio meter bottoms out, in dBFS. Quieter than this reads as silence.
    var audioFloorDecibels: Double = -50
    /// How far the meter spreads the dynamics it is given; 1 keeps the scale absolute.
    var audioExpansion: Double = 2.5
    /// Lets the meter read the material and set the two above itself.
    var audioAutoAdjusts: Bool = true
    var dimsAtNight: Bool = true
    var nightStartHour: Int = 22
    var nightEndHour: Int = 7
    var nightBrightness: Double = 0.15
    var sleepBehavior: SleepBehavior = .off
    /// Arms the device-side watchdog while the app runs, so a crash shows up as `host-gone` instead
    /// of a light that quietly keeps lying.
    var armsWatchdog: Bool = true
    /// Serial number of the device to drive; nil follows whatever is attached.
    var preferredSerialNumber: String?

    /// Brightness including the night-time reduction, which applies to every mode.
    func effectiveBrightness(at date: Date = .now, calendar: Calendar = .current) -> Double {
        guard dimsAtNight, isNight(at: date, calendar: calendar) else { return brightness }
        return min(brightness, nightBrightness)
    }

    func isNight(at date: Date = .now, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        // A window like 22…7 wraps around midnight, one like 1…5 does not.
        return nightStartHour <= nightEndHour
            ? (nightStartHour..<nightEndHour).contains(hour)
            : hour >= nightStartHour || hour < nightEndHour
    }

    // MARK: - Storage

    private static let defaultsKey = "preferences"

    static func load(from defaults: UserDefaults = .standard) -> Preferences {
        guard let data = defaults.data(forKey: defaultsKey),
              let preferences = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        return preferences
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
