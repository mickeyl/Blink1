import ArgumentParser
import Blink1
import Foundation

extension Blink1.Color: ExpressibleByArgument {

    public init?(argument: String) {
        if argument.lowercased() == "random" {
            self = .random()
            return
        }
        self.init(argument)
    }

    public static var allValueStrings: [String] { ["red", "green", "blue", "#ff8800", "255,136,0", "random"] }

    public var defaultValueDescription: String { hexString }
}

/// Wraps `Blink1.LED` rather than conforming it: ArgumentParser renders `CaseIterable` enums by raw
/// value, which would show "0" where the help should read "all".
struct LEDArgument: ExpressibleByArgument {

    let led: Blink1.LED

    init(_ led: Blink1.LED) { self.led = led }

    init?(argument: String) {
        switch argument.lowercased() {
            case "all", "both", "0": self.led = .all
            case "top", "first", "1": self.led = .top
            case "bottom", "second", "2": self.led = .bottom
            default: return nil
        }
    }

    static var allValueStrings: [String] { ["all", "top", "bottom"] }

    var defaultValueDescription: String { led.description }
}

struct StartupModeArgument: ExpressibleByArgument {

    let mode: Blink1.StartupConfiguration.Mode

    init?(argument: String) {
        guard let mode = Blink1.StartupConfiguration.Mode.allCases
            .first(where: { $0.description == argument.lowercased() }) else { return nil }
        self.mode = mode
    }

    static var allValueStrings: [String] { Blink1.StartupConfiguration.Mode.allCases.map(\.description) }

    var defaultValueDescription: String { mode.description }
}

/// A duration written the way people say it: `250ms`, `1.5s`, `2min` — a bare number means milliseconds.
struct TimeSpan: ExpressibleByArgument {

    let duration: Duration

    init(_ duration: Duration) { self.duration = duration }

    init?(argument: String) {
        let text = argument.trimmingCharacters(in: .whitespaces).lowercased()
        let (numberPart, factor): (String, Double) = if text.hasSuffix("ms") {
            (String(text.dropLast(2)), 1)
        } else if text.hasSuffix("min") {
            (String(text.dropLast(3)), 60_000)
        } else if text.hasSuffix("m") {
            (String(text.dropLast(1)), 60_000)
        } else if text.hasSuffix("s") {
            (String(text.dropLast(1)), 1_000)
        } else {
            (text, 1)
        }
        guard let value = Double(numberPart), value >= 0 else { return nil }
        self.duration = .milliseconds(Int((value * factor).rounded()))
    }

    var defaultValueDescription: String { "\(duration.blink1Milliseconds)ms" }
}
