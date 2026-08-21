import ArgumentParser
import Blink1

struct WatchdogCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "watchdog",
        abstract: "Arm the device-side watchdog (the protocol calls it \"serverdown\").",
        discussion: "Once armed, the blink(1) watches the clock itself: if no command arrives "
            + "within the timeout, it goes dark or plays a pattern — a heartbeat that keeps working "
            + "even when the machine driving it hangs. Only `watchdog arm` re-arms the timer — other "
            + "commands do not count as a sign of life.",
        subcommands: [Arm.self, Disarm.self],
        aliases: ["serverdown"])

    struct Arm: ParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "arm",
            abstract: "Start (or re-arm) the watchdog.")

        @Option(name: [.customShort("t"), .long], help: "Fire after this much silence, e.g. 30s.")
        var timeout: TimeSpan

        @Flag(name: .long, help: "Keep the current color; without it the LED goes dark right away (mk2 and later).")
        var keepColor = false

        @Option(name: .long, help: "First pattern slot to play when firing (firmware 2.05+).")
        var start: UInt8?

        @Option(name: .long, help: "Last pattern slot to play when firing (firmware 2.05+).")
        var end: UInt8?

        @OptionGroup var options: DeviceOptions

        func validate() throws {
            guard timeout.duration > .zero else { throw ValidationError("--timeout must be greater than zero") }
            guard timeout.duration <= .blink1Maximum else {
                throw ValidationError("--timeout must not exceed \(Duration.blink1Maximum.blink1Milliseconds / 1000)s")
            }
            guard (start == nil) == (end == nil) else { throw ValidationError("--start and --end go together") }
        }

        func run() throws {
            try options.withDevice { blink1 in
                let pattern: ClosedRange<UInt8>? = if let start, let end { start...end } else { nil }
                try blink1.armWatchdog(timeout: timeout.duration, keepsColor: keepColor, pattern: pattern)
                Terminal.note("watchdog armed, fires after \(timeout.duration.blink1Milliseconds)ms of silence")
            }
        }
    }

    struct Disarm: ParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "disarm",
            abstract: "Stop the watchdog.")

        @OptionGroup var options: DeviceOptions

        func run() throws {
            try options.withDevice { blink1 in
                try blink1.disarmWatchdog()
                Terminal.note("watchdog disarmed")
            }
        }
    }
}
