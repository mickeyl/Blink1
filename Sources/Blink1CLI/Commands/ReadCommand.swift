import ArgumentParser
import Blink1

struct ReadCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "read",
        abstract: "Read back the color the device currently shows.",
        discussion: "Careful with the LED argument: mk3 firmware answers with the first LED's "
            + "color no matter which LED is asked for, so both rows can read the same while the "
            + "LEDs differ.")

    @Option(name: [.customShort("l"), .long], help: "Which LED to read: top, bottom (mk2 and later).")
    var led: LEDArgument?

    @Flag(name: .long, help: "Emit JSON instead of a table.")
    var json = false

    @OptionGroup var options: DeviceOptions

    func run() throws {
        try options.withDevice { blink1 in
            let leds: [Blink1.LED] = if let led { [led.led] }
                else if blink1.model.supportsIndividualLEDs { [.top, .bottom] }
                else { [.top] }

            var readings: [Reading] = []
            for led in leds {
                let (color, fade) = try blink1.readColor(led: led)
                readings.append(Reading(led: led.description, color: color.hexString,
                                        red: color.red, green: color.green, blue: color.blue,
                                        fadeMilliseconds: fade.blink1Milliseconds))
            }

            guard !json else { return try Terminal.printJSON(readings) }
            for reading in readings {
                let color = Blink1.Color(reading.color) ?? .black
                Terminal.output(Terminal.isOutputTTY
                    ? "\(reading.led.padding(toLength: 7, withPad: " ", startingAt: 0))\(Terminal.swatch(color))\(reading.color)"
                    : "\(reading.led)\t\(reading.color)")
            }
        }
    }

    struct Reading: Encodable {
        let led: String
        let color: String
        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let fadeMilliseconds: Int
    }
}
