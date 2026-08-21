import ArgumentParser
import Blink1

@main
struct Blink1Tool: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "blink1",
        abstract: "Control a ThingM blink(1) USB RGB LED.",
        discussion: """
        EXAMPLES

          blink1 set green                      light up green
          blink1 set '#ff8800' --fade 500ms     fade to amber over half a second
          blink1 set red --led top              only the upper LED (mk2 and later)
          blink1 blink red --count 5            signal an alert
          blink1 off                            go dark
          blink1 list --json                    enumerate attached devices
          blink1 bank install                   store the status signals in the device
          blink1 signal error                   let the device signal an error by itself

        EXIT CODES

          0  success                3  device busy or access denied
          1  error                 64  usage error
          2  no blink(1) found
        """,
        version: "1.0.0",
        subcommands: [
            ListCommand.self,
            StatusCommand.self,
            SignalCommand.self,
            ClockCommand.self,
            BankCommand.self,
            InfoCommand.self,
            SetCommand.self,
            OffCommand.self,
            OnCommand.self,
            BlinkCommand.self,
            ReadCommand.self,
            PatternCommand.self,
            StartupCommand.self,
            WatchdogCommand.self,
            NoteCommand.self,
            SelfTestCommand.self,
            BootloaderCommand.self,
            RawCommand.self,
        ])
}
