import ArgumentParser
import Blink1
import Foundation

struct NoteCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "note",
        abstract: "Read or write the device's 50-byte note slots (mk3 and later).",
        discussion: "Useful to tag a device with what it is used for, so scripts can pick the right one.",
        subcommands: [Read.self, Write.self])

    struct Read: ParsableCommand {

        static let configuration = CommandConfiguration(commandName: "read", abstract: "Print a note.")

        @Argument(help: "Note slot to read.")
        var id: UInt8

        @Flag(name: .long, help: "Print raw bytes as hex instead of text.")
        var hex = false

        @OptionGroup var options: DeviceOptions

        func run() throws {
            try options.withDevice { blink1 in
                if hex {
                    let bytes = try blink1.readNote(id: id)
                    Terminal.output(bytes.map { String(format: "%02x", $0) }.joined(separator: " "))
                } else {
                    Terminal.output(try blink1.readNoteText(id: id))
                }
            }
        }
    }

    struct Write: ParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "write",
            abstract: "Store text in a note slot.",
            discussion: "Pass `-` as the text to read it from stdin.")

        @Argument(help: "Note slot to write.")
        var id: UInt8

        @Argument(help: ArgumentHelp("The text to store (max 50 bytes UTF-8), or `-` for stdin.", valueName: "text"))
        var text: String

        @OptionGroup var options: DeviceOptions

        func run() throws {
            let content: String
            if text == "-" {
                guard isatty(STDIN_FILENO) == 0 else {
                    throw ValidationError("reading from stdin, but stdin is a terminal — pipe the text in")
                }
                let data = FileHandle.standardInput.readDataToEndOfFile()
                content = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines)
            } else {
                content = text
            }
            try options.withDevice { blink1 in
                try blink1.writeNote(content, id: id)
                Terminal.note("note \(id) written")
            }
        }
    }
}
