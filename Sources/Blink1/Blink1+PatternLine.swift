import Foundation

extension Blink1 {

    /// One step of the color pattern stored inside the device.
    public struct PatternLine: Sendable, Hashable, CustomStringConvertible {

        public var color: Color
        public var fadeDuration: Duration
        /// Only meaningful on firmware 204 and later; `.all` everywhere else.
        public var led: LED

        public init(color: Color, fadeDuration: Duration = .milliseconds(300), led: LED = .all) {
            self.color = color
            self.fadeDuration = fadeDuration
            self.led = led
        }

        public var description: String { "\(color) fade \(fadeDuration.blink1Milliseconds)ms led \(led)" }
    }
}
