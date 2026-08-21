import Testing
import Foundation
@testable import Blink1

/// Talks to a real blink(1). Skipped automatically when none is attached.
/// The tests light the LED and put it back to black; nothing is written to flash.
@Suite("Attached device", .enabled(if: !Blink1.discover().isEmpty), .serialized)
struct DeviceTests {

    let device: Blink1

    init() throws {
        self.device = try Blink1.open()
    }

    @Test("reports a plausible identity")
    func identity() throws {
        #expect(device.serialNumber.count == 8)
        #expect(device.model != .unknown)
        let version = try device.firmwareVersion()
        #expect(version >= 100)
        #expect(version < 1_000)
    }

    @Test("answers the self test with the command it was given")
    func selfTest() throws {
        let response = try device.selfTest()
        #expect(response.count == Blink1.reportSize)
        #expect(response[0] == Blink1.reportID)
        #expect(response[1] == UInt8(ascii: "!"))
    }

    @Test("shows the color it was told to show")
    func setsColor() throws {
        for color in [Blink1.Color.red, .green, .blue, Blink1.Color(red: 12, green: 34, blue: 56)] {
            try device.setColor(color)
            Thread.sleep(forTimeInterval: 0.1)
            #expect(try device.readColor().color == color)
        }
        try device.turnOff()
        Thread.sleep(forTimeInterval: 0.1)
        #expect(try device.readColor().color == .black)
    }

    @Test("finishes a fade within its fade time")
    func fades() throws {
        try device.setColor(.black)
        try device.fade(to: .blue, over: .milliseconds(200))
        Thread.sleep(forTimeInterval: 0.4)
        #expect(try device.readColor().color == .blue)
        try device.turnOff()
    }

    @Test("reads back the pattern it holds")
    func readsPattern() throws {
        let pattern = try device.readPattern()
        #expect(pattern.count == device.patternSlots)
    }

    @Test("reports the state of its pattern player")
    func readsPlayState() throws {
        try device.stop()
        let state = try device.readPlayState()
        #expect(state.isPlaying == false)
    }

    @Test("stores and returns a note", .enabled(if: Blink1.discover().first?.model.supportsNotes == true))
    func note() throws {
        let previous = try device.readNote(id: 0)
        defer { try? device.writeNote(previous, id: 0) }

        try device.writeNote("blink1 swift test", id: 0)
        #expect(try device.readNoteText(id: 0) == "blink1 swift test")
    }

    @Test("has a chip id", .enabled(if: Blink1.discover().first?.model.supportsNotes == true))
    func chipID() throws {
        #expect(try device.chipID().count >= 8)
    }
}
