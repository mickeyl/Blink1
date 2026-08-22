# Blink1 — project notes

Swift package for the ThingM blink(1) USB RGB LED: library target `Blink1`, CLI target `Blink1CLI`
producing the `blink1` binary. macOS 13+, Swift 6, IOKit only (the CLI adds swift-argument-parser).

Read [PROTOCOL.md](PROTOCOL.md) before touching anything in `Sources/Blink1` — it holds the wire
format, the IOKit quirks, and firmware behaviour established by measurement rather than documentation.

## Layout

* `Sources/Blink1/HID/` — the IOKit wrapper. Nothing above it knows about `IOHIDDevice`.
* `Sources/Blink1/Blink1+Report.swift` — command bytes and report framing. All traffic goes through
  `send`/`request` (report 1) or `sendExtended`/`requestExtended` (report 2, mk3+).
* `Sources/Blink1/Blink1+{Lighting,Pattern,DeviceControl}.swift` — the commands themselves.
* `Sources/Blink1CLI/Commands/` — one file per subcommand.

## Conventions

* Public API uses typed throws (`throws(Blink1Error)`). `map`/`filter` erase typed throws to
  `any Error`, so loops are used where a closure would swallow the type.
* Capability gates go through `require(_:feature:)` (model) and `requireFirmware(_:feature:)`
  (firmware version), never a bare `if`. Unsupported means a clean error, not silence.
* The CLI follows clig.dev: primary output on stdout, chatter on stderr, `--json` for scripts, color
  only on a TTY without `NO_COLOR`, distinct exit codes (2 = no device, 3 = busy/denied).
* Destructive commands confirm unless `--force`. Locking the bootloader is deliberately library-only:
  it cannot be undone.

## Signal bank

`Blink1+Signal.swift` owns the 32-slot layout: fixed ranges per signal, so switching status is one
`play` command rather than 32 writes. Two rules the tests enforce — the ranges must partition all 32
slots, and no range may end at slot 0, because the firmware reads an end position of 0 as "play
everything". Steps carry their own duration (there is no hold), so nothing shorter than ~50ms.

Only `installSignals(persist:)` writes flash, and only when asked. The pattern a device ships with
cannot be read back, so flashing is one-way — keep `--save` behind a confirmation.

## Makefile

`make help` lists everything. Build/install/test wrap SwiftPM; the signal targets (`ok`, `busy`,
`error`, …) just play a range of the installed bank. Note `info` is taken by the device-info target,
so the info *signal* is `make info-signal`.

## Menu bar app (App/)

XcodeGen spec in `App/project.yml`, generated through `App/Scripts/generate-project.sh` (or
`make app-project`). Needs Shark 2.2.0 or later for the prebuild phase: earlier versions abort on a
project that references a local package both as a package and as a folder, which is exactly what
XcodeGen writes here.

The project lives in `App/` rather than the repository root so the package path and the project path
differ; the package itself has to stay at the root to remain consumable by SwiftPM over a URL.

Architecture: `AppModel` (@Observable, MainActor) collects what every source wants and hands the
winner to `Blink1Coordinator` (actor), the only thing that touches the device — a blink(1) answers
one report at a time.

Two traps: `MenuBarExtra` builds its content view lazily on first click, so anything that must run at
launch belongs in `Blink1BarApp.init()`, not in a `.task` on the menu. And the brightness slider must
not rewrite the bank per drag step — signals pick up a new brightness only when the drag ends.

The app is not the only thing that can reach the device, so it re-checks every 20 s whether the LED
still shows what it sent (`Blink1Coordinator.needsResync`) and takes it back if not — comparing colors
with a tolerance for PWM rounding, and signals by the pattern range being played. Without that, the
"already applied" cache would happily preserve someone else's state forever.

The watchdog heartbeat (`AppModel.feedTheWatchdog`) re-arms every 10s against a 30s timeout, so a
killed app shows up as `host-gone`. Sleep disarms it — a sleeping Mac is not a crash — and wake
reconnects from scratch. A deliberate Quit runs `prepareForTermination()`; anything that skips it
(SIGKILL) deliberately leaves the watchdog armed.

Debugging the app: `print` is block-buffered to a non-TTY, so launch the binary inside the bundle
directly and write to `FileHandle.standardError` instead. Beware of stale app copies — `open` may
launch another bundle with the same identifier from Xcode's DerivedData rather than the one just
built.

## Status arbitration

`StatusArbiter` holds one `StatusClaim` per source and picks the winner: highest priority, newest on
a tie. `AppModel.currentOutput` reads from it rather than from `preferences.mode` — the menu's mode
is just the `.ambient` claim, which is why switching modes and pushing a status no longer fight.

Adding a source means claiming and withdrawing, nothing else. Two things to keep in mind: a claim
with an expiry needs `expireClaims()` to hand the LED back (a meter happens to notice within a frame,
quiet modes would not), and anything that paints frame by frame must check `currentOutput`, not the
preference, or it will paint over a claim that outranks it.

The sources today:

* `.ambient` — the mode picked in the menu. Lowest priority; everything else is measured against it.
* `.external` or a name of its own — pushed in over the control channel (`--source ci`), priority
  from the signal: `critical` is an alert, `error`/`failure`/`host-gone` ask for attention, the rest
  are status.
* `.inputActivity` — a live microphone or camera, claimed at `.alert`. It outranks everything on
  purpose: a status taking the LED back mid-call would be a lie at the worst moment.

`InputActivityMonitor` has to skip the app's own audio tap. That aggregate device carries an input
stream, so the audio meter counted as somebody listening — which stopped the tap, cleared the claim,
restarted the tap, and oscillated once a second.

## Continuous meters (LiveMeter)

Audio, system load and network throughput are one shape of thing: two channels, a level each, painted
frame by frame. `LiveMeter` is what the single loop in `AppModel.followLiveMeter()` talks to; a meter
brings its own frame rate, fade duration, colour ramp and channel labels.

Rates are chosen against the hardware: a stereo frame costs two feature reports at ~3ms each and the
firmware's fade engine ticks every 10ms, so 30/s is the ceiling worth having and the loop must
subtract its own I/O time from the frame budget or it drifts. Slow meters (load, network at 2/s) lean
on the device interpolating between frames.

`AudioMeter` carries the parts that make the picture readable: the tap, an envelope with fast attack
and slow release, and `AudioAutoTuner`, which reads the tenth and ninety-fifth percentile of the last
half minute and sets sensitivity and dynamics from them a few times a minute. Moving a slider turns
the tuner off.

## Control channel (Sources/Blink1Control)

A Unix socket at `~/Library/Application Support/Blink1Bar/control.sock`, one JSON object per line,
mode 0600. The app serves it; the CLI forwards `signal`, `set`, `off`, `clear`, `clock`, `audio`,
`status` and `watch` through it, and `--direct` bypasses. Requests land in `AppModel.handle(_:)`,
where a signal becomes a claim (optionally named and time-limited) and a colour or mode change moves
the ambient layer.

`blink1 watch -- <command>` is the same channel from the outside: busy while the command runs,
success or failure after, output and exit code passed through, and the claim cleared if it is
interrupted. Its arguments are taken after the terminator, or `--help` would go to the command.

## Working on the protocol

`blink1 raw [--read] <hex bytes>` sends arbitrary feature reports — the fastest way to check what
firmware actually does. Note that separate CLI invocations open and close the device each time; for
back-to-back experiments use a test in `Tests/Blink1Tests` so everything happens in one session.

Quit Blink1Bar before running the hardware tests: the app owns the device and keeps re-applying its
state, which interleaves with the tests' own writes and makes them flaky. That collision is exactly
what the control channel exists to prevent — the tests bypass it on purpose.

`swift test` runs the hardware suite when a device is attached and skips it otherwise. Keep it that
way, and keep it out of flash: pattern writes stay in RAM unless a test explicitly saves. Hardware
tests must stay inside the `.serialized` suite — two instances talking to one device interleave their
feature reports and the answers come back scrambled.
