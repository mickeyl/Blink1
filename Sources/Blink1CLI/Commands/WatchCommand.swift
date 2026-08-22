import ArgumentParser
import Blink1
import Blink1Control
import Foundation

struct WatchCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "watch",
        abstract: "Run a command and show how it went.",
        discussion: "Blue while it runs, green or red when it is done — for the builds, deployments "
            + "and test runs that take long enough to look away from.\n\n"
            + "Everything the command prints goes through untouched and its exit code is passed on, "
            + "so this can be wrapped around an existing invocation without changing anything else.\n\n"
            + "  blink1 watch -- make release\n"
            + "  blink1 watch --source tests -- swift test\n"
            + "  blink1 watch --keep 2min -- ./deploy.sh")

    @Option(name: .long, help: ArgumentHelp("Name this claim, so parallel runs do not overwrite each other.",
                                            valueName: "name"))
    var source: String = "watch"

    @Option(name: .long, help: "How long the result stays after the command finished, e.g. 2min.")
    var keep: TimeSpan = TimeSpan(.seconds(60))

    @Flag(name: .long, help: "Leave the result up until something clears it.")
    var stay = false

    /// Everything after `--`, so that `blink1 watch --help` is still this command's help rather than
    /// an argument handed to whatever comes next.
    @Argument(parsing: .postTerminator,
              help: ArgumentHelp("The command to run, after --.", valueName: "command"))
    var command: [String] = []

    @OptionGroup var app: AppOptions
    @OptionGroup var options: DeviceOptions

    func validate() throws {
        guard !command.isEmpty else {
            throw ValidationError("give a command to run, after --: blink1 watch -- make all")
        }
    }

    func run() throws {
        show(.busy, duration: nil)
        // A run that is interrupted must not leave a stale "busy" on the lamp.
        let interrupts = [SIGINT, SIGTERM].map { signal in
            let source = DispatchSource.makeSignalSource(signal: signal, queue: .main)
            source.setEventHandler { [self] in
                clear()
                // Not ArgumentParser's exit(withError:): this has to leave immediately, with the
                // shell's usual code for a command that a signal ended.
                Foundation.exit(128 + signal)
            }
            source.resume()
            Foundation.signal(signal, SIG_IGN)
            return source
        }
        defer { interrupts.forEach { $0.cancel() } }

        let status = runCommand()
        show(status == 0 ? .success : .failure, duration: stay ? nil : keep.duration)
        throw ExitCode(status)
    }

    private func runCommand() -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        do {
            try process.run()
        } catch {
            Terminal.failure("could not run \(command.joined(separator: " ")): \(error.localizedDescription)")
            return 127
        }
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// Through the app when it is there, straight to the device otherwise — a wrapper around a build
    /// should work on a machine that does not run the menu bar app.
    private func show(_ signal: Blink1.Signal, duration: Duration?) {
        let seconds = duration.map { Double($0.blink1Milliseconds) / 1000 }
        switch AppBridge.forward(.signal(signal.rawValue, seconds: seconds, source: source)) {
            case .handled:
                return
            case .appNotRunning, .failed:
                try? options.withDevice { blink1 in try blink1.show(signal) }
        }
    }

    private func clear() {
        switch AppBridge.forward(.clear(source: source)) {
            case .handled:
                return
            case .appNotRunning, .failed:
                try? options.withDevice { blink1 in try blink1.turnOff() }
        }
    }
}
