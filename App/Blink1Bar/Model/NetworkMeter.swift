import Blink1
import Darwin
import Foundation
import Observation

/// What is going over the wire: incoming on the top LED, outgoing on the bottom.
///
/// The scale is logarithmic, because network rates are: a build fetching dependencies and a video
/// call differ by a factor of a hundred, and a linear meter would spend its whole range on the last
/// of them. Ten kilobytes a second is the bottom, fifty megabytes the top.
@Observable
@MainActor
final class NetworkMeter: LiveMeter {

    private(set) var levels: (left: Float, right: Float) = (0, 0)

    var currentLevels: (left: Float, right: Float) { levels }
    /// Bytes per second, for the readout in the menu.
    private(set) var rates: (incoming: Double, outgoing: Double) = (0, 0)

    private var previousCounters: (incoming: UInt64, outgoing: UInt64)?
    private var smoothed: (incoming: Float, outgoing: Float) = (0, 0)

    private static let quietBytesPerSecond = 10_000.0
    private static let loudBytesPerSecond = 50_000_000.0

    nonisolated var frameRate: Double { 2 }
    nonisolated var fadeDuration: Duration { .milliseconds(600) }
    nonisolated var channelLabels: (left: String, right: String) { ("IN", "OUT") }

    func start() throws {
        previousCounters = nil
        smoothed = (0, 0)
    }

    func stop() {
        levels = (0, 0)
        rates = (0, 0)
    }

    func levels(elapsed: TimeInterval) -> (left: Float, right: Float)? {
        guard let counters = interfaceCounters(), elapsed > 0 else { return nil }
        defer { previousCounters = counters }
        guard let previous = previousCounters else { return nil }

        rates = (Double(counters.incoming &- previous.incoming) / elapsed,
                 Double(counters.outgoing &- previous.outgoing) / elapsed)

        let coefficient = Float(1 - exp(-elapsed / 0.6))
        smoothed.incoming += (scale(rates.incoming) - smoothed.incoming) * coefficient
        smoothed.outgoing += (scale(rates.outgoing) - smoothed.outgoing) * coefficient
        levels = (left: smoothed.incoming, right: smoothed.outgoing)
        return levels
    }

    nonisolated func color(for level: Float) -> Blink1.Color {
        Blink1.Color(flowLevel: level)
    }

    private func scale(_ bytesPerSecond: Double) -> Float {
        guard bytesPerSecond > Self.quietBytesPerSecond else { return 0 }
        let span = log10(Self.loudBytesPerSecond / Self.quietBytesPerSecond)
        return Float(min(max(log10(bytesPerSecond / Self.quietBytesPerSecond) / span, 0), 1))
    }

    /// Every interface the kernel counts bytes for, minus loopback — traffic that never left the
    /// machine is not what this meter is about.
    private func interfaceCounters() -> (incoming: UInt64, outgoing: UInt64)? {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return nil }
        defer { freeifaddrs(addresses) }

        var incoming: UInt64 = 0
        var outgoing: UInt64 = 0
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let address = interface.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: interface.ifa_name)
            guard !name.hasPrefix("lo"), let data = interface.ifa_data else { continue }

            let counters = data.assumingMemoryBound(to: if_data.self).pointee
            incoming += UInt64(counters.ifi_ibytes)
            outgoing += UInt64(counters.ifi_obytes)
        }
        return (incoming, outgoing)
    }
}
