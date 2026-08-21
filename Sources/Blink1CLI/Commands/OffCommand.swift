import ArgumentParser
import Blink1
import Blink1Control

struct OffCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "off",
        abstract: "Turn the device off and stop any running pattern.")

    @Option(name: [.customShort("f"), .long], help: "Fade out over this time, e.g. 500ms.")
    var fade: TimeSpan = TimeSpan(.zero)

    @OptionGroup var app: AppOptions
    @OptionGroup var options: DeviceOptions

    func run() throws {
        guard try !app.forwarded(.off) else { return }
        try options.withDevice { blink1 in
            try blink1.stop()
            if fade.duration == .zero {
                try blink1.turnOff()
            } else {
                try blink1.fade(to: .black, over: fade.duration)
            }
            Terminal.note("off")
        }
    }
}
