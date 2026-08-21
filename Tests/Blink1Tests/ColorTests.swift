import Testing
@testable import Blink1

@Suite("Color")
struct ColorTests {

    @Test("parses hex in all accepted spellings", arguments: [
        ("#ff8800", Blink1.Color(red: 255, green: 136, blue: 0)),
        ("ff8800", Blink1.Color(red: 255, green: 136, blue: 0)),
        ("#f80", Blink1.Color(red: 255, green: 136, blue: 0)),
        ("F80", Blink1.Color(red: 255, green: 136, blue: 0)),
        ("#000000", .black),
        ("#ffffff", .white),
    ])
    func parsesHex(input: String, expected: Blink1.Color) {
        #expect(Blink1.Color(input) == expected)
    }

    @Test("parses decimal triplets and names")
    func parsesTripletsAndNames() {
        #expect(Blink1.Color("255,136,0") == Blink1.Color(red: 255, green: 136, blue: 0))
        #expect(Blink1.Color(" 0, 0 ,255 ") == .blue)
        #expect(Blink1.Color("red") == .red)
        #expect(Blink1.Color("OFF") == .black)
    }

    @Test("rejects nonsense", arguments: ["", "#ff88", "nope", "300,0,0", "#gg0000", "1,2"])
    func rejectsNonsense(input: String) {
        #expect(Blink1.Color(input) == nil)
    }

    @Test("round-trips through its hex string")
    func roundTripsHex() {
        let color = Blink1.Color(red: 18, green: 200, blue: 7)
        #expect(Blink1.Color(color.hexString) == color)
    }

    @Test("converts HSB to the expected primaries")
    func convertsHSB() {
        #expect(Blink1.Color(hue: 0, saturation: 1, brightness: 1) == .red)
        #expect(Blink1.Color(hue: 1.0 / 3, saturation: 1, brightness: 1) == .green)
        #expect(Blink1.Color(hue: 2.0 / 3, saturation: 1, brightness: 1) == .blue)
        #expect(Blink1.Color(hue: 0.5, saturation: 0, brightness: 1) == .white)
        #expect(Blink1.Color(hue: 0.5, saturation: 1, brightness: 0) == .black)
    }

    @Test("dims linearly and clamps its factor")
    func dims() {
        #expect(Blink1.Color.white.dimmed(to: 0.5) == Blink1.Color(red: 128, green: 128, blue: 128))
        #expect(Blink1.Color.white.dimmed(to: 0) == .black)
        #expect(Blink1.Color.white.dimmed(to: 2) == .white)
        #expect(Blink1.Color.white.dimmed(to: -1) == .black)
    }
}
