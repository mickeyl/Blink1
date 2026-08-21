import ArgumentParser
import Blink1

struct BootloaderCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "bootloader",
        abstract: "Reboot the device into its USB bootloader (mk3 and later).",
        discussion: "The blink(1) leaves the USB bus and comes back as a bootloader volume for "
            + "a firmware update. Unplug and replug it to get the LED back.\n\n"
            + "Locking the bootloader permanently is deliberately not exposed here — it cannot be "
            + "undone in software and would make firmware updates impossible. The library offers it "
            + "as `lockBootloader()` for anyone who really means it.")

    @Flag(name: [.customShort("f"), .long], help: "Skip the confirmation prompt.")
    var force = false

    @OptionGroup var options: DeviceOptions

    func run() throws {
        try options.withDevice { blink1 in
            guard force || Terminal.confirm("Reboot \(blink1.serialNumber) into the bootloader?") else {
                Terminal.failure("aborted", hint: "Pass --force to skip this prompt.")
                throw ExitCode(1)
            }
            try blink1.enterBootloader()
            Terminal.note("device is in the bootloader — replug it to return to normal operation")
        }
    }
}
