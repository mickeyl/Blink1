import Blink1
import Foundation

/// stdout/stderr discipline, TTY detection and color handling for the tool.
enum Terminal {

    /// Set from `--no-color`.
    nonisolated(unsafe) static var colorSuppressed = false
    /// Set from `--quiet`.
    nonisolated(unsafe) static var quiet = false

    static var isOutputTTY: Bool { isatty(STDOUT_FILENO) == 1 }

    static var usesColor: Bool {
        guard !colorSuppressed, isOutputTTY else { return false }
        let environment = ProcessInfo.processInfo.environment
        guard environment["NO_COLOR"]?.isEmpty ?? true else { return false }
        return environment["TERM"] != "dumb"
    }

    /// Primary output.
    static func output(_ line: String) {
        print(line)
    }

    /// Status chatter — never on stdout, so piping stays clean.
    static func note(_ line: String) {
        guard !quiet else { return }
        FileHandle.standardError.write(Data("\(line)\n".utf8))
    }

    static func failure(_ message: String, hint: String? = nil) {
        let label = usesColorOnError ? "\u{1B}[31merror:\u{1B}[0m" : "error:"
        var text = "\(label) \(message)\n"
        if let hint { text += "hint: \(hint)\n" }
        FileHandle.standardError.write(Data(text.utf8))
    }

    private static var usesColorOnError: Bool {
        guard !colorSuppressed, isatty(STDERR_FILENO) == 1 else { return false }
        let environment = ProcessInfo.processInfo.environment
        guard environment["NO_COLOR"]?.isEmpty ?? true else { return false }
        return environment["TERM"] != "dumb"
    }

    /// A colored block rendering the given color, or its hex string on a dumb terminal.
    static func swatch(_ color: Blink1.Color) -> String {
        guard usesColor else { return "" }
        return "\u{1B}[38;2;\(color.red);\(color.green);\(color.blue)m██\u{1B}[0m "
    }

    static func printJSON(_ value: some Encodable) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        print(String(decoding: data, as: UTF8.self))
    }

    /// Asks for confirmation, but only when a human is watching.
    static func confirm(_ question: String) -> Bool {
        guard isatty(STDIN_FILENO) == 1 else { return false }
        FileHandle.standardError.write(Data("\(question) [y/N] ".utf8))
        guard let answer = readLine(strippingNewline: true)?.lowercased() else { return false }
        return answer == "y" || answer == "yes"
    }
}
