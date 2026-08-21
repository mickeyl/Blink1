import Foundation

extension Blink1 {

    /// Fades to `color` over `duration`.
    ///
    /// This is the workhorse command: a fade of zero is the fastest way to change color while still
    /// being able to address a single LED.
    /// - Parameter led: mk2 and later only; ignored by mk1 firmware.
    public func fade(to color: Color, over duration: Duration = .zero, led: LED = .all) throws(Blink1Error) {
        let color = transmittable(color)
        let ticks = duration.blink1Ticks
        try send(.fadeToRGB, color.red, color.green, color.blue, UInt8(ticks >> 8), UInt8(ticks & 0xFF), led.rawValue)
    }

    /// Sets all LEDs to `color` immediately, aborting any running fade or pattern.
    public func setColor(_ color: Color) throws(Blink1Error) {
        let color = transmittable(color)
        try send(.setRGBNow, color.red, color.green, color.blue)
    }

    /// Turns the device off.
    public func turnOff() throws(Blink1Error) { try setColor(.black) }

    /// The color an LED currently shows, plus the fade still in progress.
    public func readColor(led: LED = .top) throws(Blink1Error) -> (color: Color, fadeDuration: Duration) {
        guard model != .mk1 else { return try readColorMk1() }
        let response = try request(.readRGB, 0, 0, 0, 0, 0, led.rawValue)
        let ticks = UInt16(response[5]) << 8 | UInt16(response[6])
        return (Color(red: response[2], green: response[3], blue: response[4]), Duration(blink1Ticks: ticks))
    }

    /// mk1 firmware has no read command; the current color simply lingers in the report buffer.
    private func readColorMk1() throws(Blink1Error) -> (color: Color, fadeDuration: Duration) {
        Thread.sleep(forTimeInterval: 0.05)
        do {
            let response = try hid.featureReport(id: Self.reportID, length: Self.reportSize)
            guard response.count == Self.reportSize else { throw Blink1Error.malformedResponse }
            return (Color(red: response[2], green: response[3], blue: response[4]), .zero)
        } catch let error as HIDError {
            throw Blink1Error(error)
        } catch {
            throw .malformedResponse
        }
    }

    /// Blinks `color` synchronously, leaving the device off afterwards.
    ///
    /// Blocking by design: a status blink is short and the caller usually wants it finished before moving on.
    /// For long or endless signalling store a pattern and let the device play it.
    public func blink(_ color: Color, times: Int = 3, period: Duration = .milliseconds(400)) throws(Blink1Error) {
        let halfPeriod = max(period.blink1Milliseconds / 2, 1)
        for iteration in 0..<max(times, 1) {
            if iteration > 0 { Thread.sleep(forTimeInterval: Double(halfPeriod) / 1000) }
            try setColor(color)
            Thread.sleep(forTimeInterval: Double(halfPeriod) / 1000)
            try setColor(.black)
        }
    }
}
