import AudioToolbox
import CoreAudio
import Foundation
import os

/// Taps everything the system plays and keeps the current stereo level around.
///
/// The tap is a `CATapDescription` wrapped in a private aggregate device — the documented way to
/// listen in on system output since macOS 14.2, and unlike a virtual audio driver it needs nothing
/// installed. `CATapUnmuted` means the audio still reaches the speakers while we look at it.
///
/// Levels are computed in the IO callback, which runs on a realtime thread: it may not allocate,
/// lock for long, or hop to another executor. So it writes into a lock-protected pair of floats that
/// the display side polls at its own pace, and nothing else.
nonisolated final class SystemAudioTap {

    struct Levels: Sendable {
        var left: Float = 0
        var right: Float = 0
    }

    enum Failure: Error, CustomStringConvertible {

        case noOutputDevice
        case coreAudio(String, OSStatus)

        var description: String {
            switch self {
                case .noOutputDevice: "no audio output device"
                case .coreAudio(let call, let status): "\(call) failed (\(status))"
            }
        }
    }

    private let levels = OSAllocatedUnfairLock(initialState: Levels())
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    var currentLevels: Levels { levels.withLock { $0 } }

    /// The aggregate device carrying the tap. It has an input stream, so anything looking for a live
    /// microphone has to know to skip it — otherwise this app watching the output counts as one.
    var deviceID: AudioObjectID? {
        aggregateID == AudioObjectID(kAudioObjectUnknown) ? nil : aggregateID
    }

    var isRunning: Bool { ioProcID != nil }

    deinit { stop() }

    func start() throws(Failure) {
        guard !isRunning else { return }
        do {
            try openTap()
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if let ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            self.ioProcID = nil
        }
        if aggregateID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        levels.withLock { $0 = Levels() }
    }

    private func openTap() throws(Failure) {
        let outputUID = try defaultOutputDeviceUID()

        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.name = "Blink1Bar"
        description.muteBehavior = .unmuted
        // Private: the aggregate below is ours alone and has no business showing up in Sound settings.
        description.isPrivate = true

        var status = AudioHardwareCreateProcessTap(description, &tapID)
        guard status == noErr else { throw .coreAudio("AudioHardwareCreateProcessTap", status) }

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Blink1Bar Audio Tap",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: description.uuid.uuidString,
            ]],
        ]
        status = AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID)
        guard status == noErr else { throw .coreAudio("AudioHardwareCreateAggregateDevice", status) }

        let levels = self.levels
        status = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, nil) { _, input, _, _, _ in
            guard let measured = Self.measure(input) else { return }
            levels.withLock { $0 = measured }
        }
        guard status == noErr, let ioProcID else {
            throw .coreAudio("AudioDeviceCreateIOProcIDWithBlock", status)
        }

        status = AudioDeviceStart(aggregateID, ioProcID)
        guard status == noErr else { throw .coreAudio("AudioDeviceStart", status) }
    }

    /// RMS per channel. Runs on the audio thread: no allocation, no locking beyond the store above.
    private static func measure(_ bufferList: UnsafePointer<AudioBufferList>) -> Levels? {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: bufferList))
        guard let first = buffers.first, first.mDataByteSize > 0 else { return nil }

        func rms(_ samples: UnsafeBufferPointer<Float>, stride: Int, offset: Int) -> Float {
            var sum: Float = 0
            var count = 0
            var index = offset
            while index < samples.count {
                let sample = samples[index]
                sum += sample * sample
                count += 1
                index += stride
            }
            return count > 0 ? (sum / Float(count)).squareRoot() : 0
        }

        if buffers.count >= 2 {
            // One buffer per channel.
            let left = UnsafeBufferPointer<Float>(start: buffers[0].mData?.assumingMemoryBound(to: Float.self),
                                                  count: Int(buffers[0].mDataByteSize) / MemoryLayout<Float>.size)
            let right = UnsafeBufferPointer<Float>(start: buffers[1].mData?.assumingMemoryBound(to: Float.self),
                                                   count: Int(buffers[1].mDataByteSize) / MemoryLayout<Float>.size)
            return Levels(left: rms(left, stride: 1, offset: 0), right: rms(right, stride: 1, offset: 0))
        }

        // A single interleaved buffer.
        let channels = Int(first.mNumberChannels)
        let samples = UnsafeBufferPointer<Float>(start: first.mData?.assumingMemoryBound(to: Float.self),
                                                 count: Int(first.mDataByteSize) / MemoryLayout<Float>.size)
        guard channels > 1 else {
            let mono = rms(samples, stride: 1, offset: 0)
            return Levels(left: mono, right: mono)
        }
        return Levels(left: rms(samples, stride: channels, offset: 0),
                      right: rms(samples, stride: channels, offset: 1))
    }

    private func defaultOutputDeviceUID() throws(Failure) -> String {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                                &address, 0, nil, &size, &deviceID)
        guard status == noErr, deviceID != AudioObjectID(kAudioObjectUnknown) else { throw .noOutputDevice }

        address.mSelector = kAudioDevicePropertyDeviceUID
        var uid: CFString = "" as CFString
        size = UInt32(MemoryLayout<CFString>.size)
        status = withUnsafeMutablePointer(to: &uid) {
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, $0)
        }
        guard status == noErr else { throw .coreAudio("kAudioDevicePropertyDeviceUID", status) }
        return uid as String
    }
}
