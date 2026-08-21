import Blink1

/// What the LED should show right now — the single value everything in the app boils down to.
enum DeviceOutput: Equatable, Sendable {

    case off
    /// A steady color, chosen by hand or derived from the clock.
    case color(Blink1.Color)
    /// One of the signals stored in the device's bank.
    case signal(Blink1.Signal)

    /// The color to tint the menu bar icon with — an approximation for signals, which move.
    var indicatorColor: Blink1.Color {
        switch self {
            case .off: .black
            case .color(let color): color
            case .signal(let signal): signal.steps().first(where: { !$0.color.isBlack })?.color ?? .black
        }
    }
}
