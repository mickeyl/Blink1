# The blink(1) USB protocol

Everything this package relies on, verified against a blink(1) mk3 (firmware 3.3, serial `36cf12c4`)
on macOS 26. Sources: the [official HID command
document](https://github.com/todbot/blink1/blob/main/docs/blink1-hid-commands.md), the reference
implementation [`blink1-lib`](https://github.com/todbot/blink1-tool), and direct measurement.

## The device

| | |
|---|---|
| Vendor ID | `0x27B8` (ThingM) |
| Product ID | `0x01ED` |
| Transport | USB HID, no driver, no entitlement |
| HID usage page | `0xFFAB`, usage `0x2000` (vendor defined) |
| Serial number | 8 hex digits, also encodes the hardware generation |

Because the usage page is vendor-defined rather than a generic desktop or keyboard page, macOS hands
the device out without the *Input Monitoring* privilege. `IOHIDManager` with a VID/PID match is all
it takes.

The report descriptor (`06 ab ff 0a 00 20 a1 01 15 00 26 ff 00 75 08 85 01 95 08 09 00 b2 02 01
75 08 85 02 95 3c 09 00 b2 02 01 c0`) declares exactly two feature reports:

| Report ID | Payload | Used for |
|---|---|---|
| `1` | 8 bytes | every regular command |
| `2` | 60 bytes | mk3+ extras: notes, chip id, bootloader |

There are no input or output reports — the device never talks unasked.

## Wire format

A report-1 packet, as it appears on the bus, is the report ID followed by 8 payload bytes:

```
byte 0   report id (0x01)
byte 1   command, an ASCII character ('c' = 0x63 = fade to RGB)
byte 2   argument 0   (e.g. red)
byte 3   argument 1   (e.g. green)
byte 4   argument 2   (e.g. blue)
byte 5   argument 3   (e.g. fade time, high byte)
byte 6   argument 4   (e.g. fade time, low byte)
byte 7   argument 5   (e.g. which LED)
byte 8   padding, always zero
```

The protocol document counts bytes 0–7 as "the packet" and the firmware never looks at byte 8, but
the descriptor asks for 8 payload bytes, so 9 bytes go over the wire.

**Unused arguments must be zero.** Several commands misbehave when they are not.

### Reading

There is no interrupt endpoint. A read is *SET_REPORT followed by GET_REPORT*: the command packet is
sent as a feature report, the firmware prepares its answer, and the answer is fetched with a second
transfer. The answer echoes the report ID in byte 0 and the command in byte 1.

### macOS/IOKit specifics

Two details that cost debugging time and are not written down anywhere:

* `IOHIDDeviceSetReport` expects the report ID *inside* the buffer as byte 0 **and** as the separate
  `reportID` argument. The buffer is 9 bytes long, not 8.
* `IOHIDDeviceGetReport` writes the report ID into byte 0 of the buffer but reports back a length
  that **excludes** it — a 9-byte buffer comes back with `reportLength == 8`. Truncating the buffer
  to that length drops the last argument. `Sources/Blink1/HID/HIDDevice.swift` keeps the full buffer
  instead.

### Time encoding

All timings are a 16-bit count of 10ms ticks, split into two bytes:

```
th = (milliseconds / 10) >> 8
tl = (milliseconds / 10) & 0xff
```

Division truncates, so 9ms becomes 0. The longest expressible time is `0xFFFF` ticks = 655,350ms ≈
10.9 minutes. Firmware 2.04 has a bug that caps watchdog timeouts near 62 seconds.

## Commands

`n` = LED (0 = all, 1 = first, 2 = second), `p` = pattern position, `th/tl` = time,
`sp/ep` = start/end position, `c` = repeat count.

| Command | Bytes | Answer | Since |
|---|---|---|---|
| Fade to RGB | `1 'c' r g b th tl n` | — | all |
| Set RGB now | `1 'n' r g b 0 0 0` | — | all |
| Read current RGB | `1 'r' 0 0 0 0 0 n` | `1 'r' r g b th tl n` | mk2 |
| Serverdown (watchdog) | `1 'D' on th tl st sp ep` | — | all (`st` mk2+, `sp/ep` fw 2.05+) |
| Play/pause pattern | `1 'p' on sp ep c 0 0` | — | mk2 (mk1: play from position only) |
| Read play state | `1 'S' 0 0 0 0 0 0` | `1 'S' playing sp ep count pos 0` | mk2 |
| Write pattern line | `1 'P' r g b th tl p` | — | all |
| Read pattern line | `1 'R' 0 0 0 0 0 p` | `1 'R' r g b th tl n` | all |
| Save pattern to flash | `1 'W' 0xBE 0xEF 0xCA 0xFE 0 0` | — | mk2 |
| Set LED for next write | `1 'l' n 0 0 0 0 0` | — | fw 2.04+ |
| Read EEPROM | `1 'e' addr 0 0 0 0 0` | `1 'e' addr value …` | mk1 only |
| Write EEPROM | `1 'E' addr value 0 0 0 0` | — | mk1 only |
| Firmware version | `1 'v' 0 0 0 0 0 0` | `1 'v' ? major minor …` (ASCII) | all |
| Self test | `1 '!' 0 0 0 0 0 0` | `1 '!' …` | all |
| Set startup params | `1 'B' mode sp ep c 0 0` | — | fw 2.06+ |
| Get startup params | `1 'b' 0 0 0 0 0 0` | `1 'b' mode sp ep c …` | fw 2.06+ |
| Write note | `2 'F' id <50 bytes>` | — | mk3 |
| Read note | `2 'f' id …` | `2 'f' id <50 bytes>` | mk3 |
| Chip unique id | `2 'U' 0 …` | `2 'U' <id bytes>` | mk3 |
| Go to bootloader | `2 'G' 'o' 'B' 'o' 'o' 't' 0` | `2 "GOBOOT"` or nothing when locked | mk3 |
| Lock bootloader | `2 'L' "ockBootload"` | `2 "LOCKED"` | mk3, irreversible |

The protocol document lists "go to bootloader" on report 1; the reference implementation sends it on
report 2, and that is what works.

### Firmware version

Returned as two ASCII digits in bytes 3 and 4, so `'3','3'` means firmware 3.3. `blink1-lib` scales
it to an integer (303), which is what the capability checks compare against.

### Saving patterns

`'W'` erases and reprograms flash, which takes longer than the USB control transfer timeout. The
SET_REPORT therefore fails even though the write succeeds — the error must be ignored. Give the
device ~100ms before talking to it again.

## Hardware generations

The generation is derived from the serial number, not from the USB descriptors:

| Serial number | Model | LEDs | Pattern slots | Gamma correction |
|---|---|---|---|---|
| `< 0x20000000` | mk1 | 1 | 16 | on the host |
| `≥ 0x20000000` | mk2 | 2 | 16 | in firmware |
| `≥ 0x30000000` | mk3 | 2 | 32 | in firmware |
| `≥ 0x40000000` | mk4 | 2 | 32 | in firmware |

mk1 devices expect the host to apply a perceptual curve before sending RGB values; later firmware
does it itself, so a host-side curve would be applied twice. `Sources/Blink1/Gamma.swift` carries the
table from `blink1-lib` and the library enables it only for mk1.

## Measured firmware behaviour (mk3, firmware 3.3)

Things the documentation does not mention, established by experiment:

* **Per-LED addressing works for writes.** `'c'` with `n = 1` changes that LED alone — verified by
  read-back — with or without a fade time. `n = 2` is accepted the same way; it cannot be confirmed
  through the protocol because of the next point.
* **Read-back ignores the LED argument.** `'r'` returns the color of the first LED whatever `n` is,
  and echoes `n = 1` in byte 7 for any `n ≥ 2`. There is no way to read the second LED's color.
* **`'l'` (set LED) is sticky.** It is not a per-write modifier that resets: whatever it was last set
  to applies to every following `'P'` write. A line written without setting it first silently
  inherits the previous line's LED, so `writePatternLine()` always sends it.
* Reading a pattern line answers with the LED in byte 7 — one-based, `0` meaning both.
* **The play range's end position is inclusive.** `'p'` with `sp = 0, ep = 1` plays slots 0 *and* 1,
  so a 32-slot device plays everything with `ep = 31`, not 32. The document's "end loop position
  (1 - patt_max)" reads like a count, which it is not.
* The play position in the `'S'` answer is stale once playback stops — only read it while playing.
* **An end position of 0 means "play the whole pattern".** `'p'` with `sp = 0, ep = 0` cycles all 32
  slots, not just slot 0 — the same convention the document spells out for the watchdog's `sp/ep`.
  Slot 0 therefore cannot be played on its own; `sp = ep = n` works for every other slot.
* **The watchdog plays exactly the range it was armed with.** `'D'` with `sp/ep` set starts that
  pattern range, endlessly, when the timeout expires — measured with `sp = 2, ep = 3`.
* **Only `'D'` tickles the watchdog.** Other traffic does not reset the countdown: two seconds of
  read commands went by and the watchdog still fired on schedule.
* **`st = 0` blanks the LED the moment the watchdog is armed**, not when it fires. With `st = 1` the
  current color stays. So "maintain state" governs arming as much as firing.
