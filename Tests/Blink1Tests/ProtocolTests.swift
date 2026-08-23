import Testing
import Foundation
@testable import Blink1

@Suite("Protocol encoding")
struct ProtocolTests {

    @Test("encodes fade times as 10ms ticks", arguments: [
        (Duration.zero, UInt16(0)),
        (.milliseconds(10), 1),
        (.milliseconds(100), 10),
        (.milliseconds(500), 50),
        (.seconds(5), 500),
        (.milliseconds(9), 0),      // rounds towards zero, like the reference implementation
        (.milliseconds(19), 1),
    ])
    func encodesTicks(duration: Duration, expected: UInt16) {
        #expect(duration.blink1Ticks == expected)
    }

    @Test("clamps timings the 16-bit tick counter cannot express")
    func clampsTicks() {
        #expect(Duration.seconds(-1).blink1Ticks == 0)
        #expect(Duration.seconds(3_600).blink1Ticks == 0xFFFF)
        #expect(Duration.blink1Maximum.blink1Ticks == 0xFFFF)
    }

    @Test("round-trips ticks back into a duration")
    func roundTripsTicks() {
        #expect(Duration(blink1Ticks: 50) == .milliseconds(500))
        #expect(Duration(blink1Ticks: 0xFFFF).blink1Milliseconds == 655_350)
    }

    @Test("derives the model from the serial number", arguments: [
        ("1a2b3c4d", Blink1.Model.mk1),
        ("0f000000", .mk1),
        ("20000000", .mk2),
        ("2abcdef0", .mk2),
        ("30000000", .mk3),
        ("36cf12c4", .mk3),
        ("40000000", .mk4),
        ("nonsense", .unknown),
    ])
    func derivesModel(serial: String, expected: Blink1.Model) {
        #expect(Blink1.Model(serialNumber: serial) == expected)
    }

    @Test("knows each model's capabilities")
    func knowsCapabilities() {
        #expect(Blink1.Model.mk1.ledCount == 1)
        #expect(Blink1.Model.mk3.ledCount == 2)
        #expect(Blink1.Model.mk1.patternSlots == 16)
        #expect(Blink1.Model.mk3.patternSlots == 32)
        #expect(Blink1.Model.mk1.correctsGammaInFirmware == false)
        #expect(Blink1.Model.mk2.correctsGammaInFirmware)
        #expect(Blink1.Model.mk2.supportsNotes == false)
        #expect(Blink1.Model.mk3.supportsNotes)
    }

    @Test("decodes a valid pattern-player response")
    func decodesPlayState() throws {
        let response: [UInt8] = [1, UInt8(ascii: "S"), 1, 2, 7, 0, 4, 0]
        let state = try Blink1.decodePlayState(response, patternSlots: 32)

        #expect(state.isPlaying)
        #expect(state.startPosition == 2)
        #expect(state.endPosition == 7)
        #expect(state.currentPosition == 4)
    }

    @Test("allows the firmware's stale position after playback stops")
    func decodesStoppedPlayState() throws {
        let response: [UInt8] = [1, UInt8(ascii: "S"), 0, 0, 31, 0, 213, 0]
        let state = try Blink1.decodePlayState(response, patternSlots: 32)

        #expect(state.isPlaying == false)
    }

    @Test("rejects scrambled pattern-player responses", arguments: [
        [UInt8](arrayLiteral: 1, UInt8(ascii: "S"), 217, 0, 31, 0, 4, 0),
        [UInt8](arrayLiteral: 1, UInt8(ascii: "S"), 1, 0, 31, 0, 213, 0),
        [UInt8](arrayLiteral: 1, UInt8(ascii: "S"), 1, 0, 32, 0, 4, 0),
    ])
    func rejectsMalformedPlayState(response: [UInt8]) {
        #expect(throws: Blink1Error.self) {
            try Blink1.decodePlayState(response, patternSlots: 32)
        }
    }

    @Test("keeps the gamma curve monotonic between the expected endpoints")
    func gammaCurve() {
        #expect(Gamma.corrected(0) == 0)
        #expect(Gamma.corrected(255) == 255)
        var previous = UInt8(0)
        for value in 0...255 {
            let corrected = Gamma.corrected(UInt8(value))
            #expect(corrected >= previous)
            #expect(corrected <= UInt8(value))
            previous = corrected
        }
    }
}
