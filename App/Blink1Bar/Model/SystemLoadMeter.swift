import Blink1
import Darwin
import Foundation
import Observation

/// The machine's own mood: processor on the top LED, memory on the bottom.
///
/// Both are read straight from the kernel, so this costs nothing and needs nothing granted. Slow on
/// purpose — a load meter that flickers with every scheduler decision says less than one that shows
/// the trend.
@Observable
@MainActor
final class SystemLoadMeter: LiveMeter {

    private(set) var levels: (left: Float, right: Float) = (0, 0)

    var currentLevels: (left: Float, right: Float) { levels }

    private var previousTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    /// Smooths the processor reading; memory moves slowly enough on its own.
    private var smoothedLoad: Float = 0

    nonisolated var frameRate: Double { 2 }
    nonisolated var fadeDuration: Duration { .milliseconds(700) }
    nonisolated var channelLabels: (left: String, right: String) { ("CPU", "MEM") }

    func start() throws {
        previousTicks = nil
        smoothedLoad = 0
    }

    func stop() {
        levels = (0, 0)
    }

    func levels(elapsed: TimeInterval) -> (left: Float, right: Float)? {
        guard let load = processorLoad() else { return nil }
        // Half a second of smoothing: enough to stop the twitching, short enough to see a build start.
        let coefficient = Float(1 - exp(-elapsed / 0.5))
        smoothedLoad += (load - smoothedLoad) * coefficient
        levels = (smoothedLoad, memoryPressure())
        return levels
    }

    nonisolated func color(for level: Float) -> Blink1.Color {
        Blink1.Color(meterLevel: level)
    }

    /// Busy ticks against all ticks since the last look — the same arithmetic `top` does.
    private func processorLoad() -> Float? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let ticks = (user: info.cpu_ticks.0, system: info.cpu_ticks.1, idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
        defer { previousTicks = ticks }
        guard let previous = previousTicks else { return nil }

        let busy = Float((ticks.user &- previous.user) + (ticks.system &- previous.system) + (ticks.nice &- previous.nice))
        let idle = Float(ticks.idle &- previous.idle)
        let total = busy + idle
        guard total > 0 else { return nil }
        return min(max(busy / total, 0), 1)
    }

    /// What the machine has actually spoken for: resident, wired and compressed pages.
    private func memoryPressure() -> Float {
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return levels.right }

        let pageSize = Float(sysconf(_SC_PAGESIZE))
        let used = (Float(statistics.active_count) + Float(statistics.wire_count)
            + Float(statistics.compressor_page_count)) * pageSize
        let total = Float(ProcessInfo.processInfo.physicalMemory)
        guard total > 0 else { return levels.right }
        return min(max(used / total, 0), 1)
    }
}
