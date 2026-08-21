import ArgumentParser
import Blink1
import Blink1Control

struct SetCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Light the device in a color.",
        discussion: "Colors are names (red, green, blue, yellow, cyan, magenta, orange, amber, "
            + "purple, pink, teal, lime, white, black), hex (#ff8800, ff8800, #f80) or decimal "
            + "triplets (255,136,0). The literal `random` picks one.")

    @Argument(help: ArgumentHelp("The color to show.", valueName: "color"))
    var color: Blink1.Color

    @Option(name: [.customShort("f"), .long], help: "Fade time, e.g. 250ms, 1.5s.")
    var fade: TimeSpan = TimeSpan(.zero)

    @Option(name: [.customShort("l"), .long], help: "Which LED to address: all, top, bottom.")
    var led: LEDArgument = LEDArgument(.all)

    @Option(name: [.customShort("b"), .long], help: "Scale brightness, 0.0 to 1.0.")
    var brightness: Double?

    @OptionGroup var app: AppOptions
    @OptionGroup var options: DeviceOptions

    func validate() throws {
        if let brightness, !(0...1).contains(brightness) {
            throw ValidationError("brightness must be between 0.0 and 1.0")
        }
    }

    func run() throws {
        let color = brightness.map { color.dimmed(to: $0) } ?? color
        // A single LED and a single owner: while the app runs, it decides what is shown.
        guard try !app.forwarded(.color(color.hexString)) else { return }
        try options.withDevice { blink1 in
            // 'set now' is the only command that also cancels a running pattern.
            if fade.duration == .zero, led.led == .all {
                try blink1.setColor(color)
            } else {
                try blink1.fade(to: color, over: fade.duration, led: led.led)
            }
            Terminal.note("\(Terminal.swatch(color))\(color.hexString) on \(blink1.serialNumber)")
        }
    }
}
