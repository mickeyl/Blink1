import ArgumentParser
import Blink1

struct OnCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "on",
        abstract: "Light the device white.")

    @Option(name: [.customShort("b"), .long], help: "Scale brightness, 0.0 to 1.0.")
    var brightness: Double = 1.0

    @Option(name: [.customShort("f"), .long], help: "Fade in over this time, e.g. 500ms.")
    var fade: TimeSpan = TimeSpan(.zero)

    @OptionGroup var options: DeviceOptions

    func validate() throws {
        guard (0...1).contains(brightness) else { throw ValidationError("brightness must be between 0.0 and 1.0") }
    }

    func run() throws {
        let color = Blink1.Color.white.dimmed(to: brightness)
        try options.withDevice { blink1 in
            try blink1.fade(to: color, over: fade.duration)
            Terminal.note("\(Terminal.swatch(color))\(color.hexString)")
        }
    }
}
