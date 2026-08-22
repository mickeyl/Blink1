import AVFoundation
import CoreAudio
import Foundation

/// Watches whether anything on this Mac is listening or looking.
///
/// This is the one signal the LED sends to the room rather than to its owner: it tells the people
/// around you that the microphone is live, which is exactly what a small lamp on a desk is good at.
///
/// Core Audio answers it directly — `kAudioDevicePropertyDeviceIsRunningSomewhere` is true while any
/// process has the input running — so there is no polling of process lists and, notably, no
/// permission needed to ask.
@MainActor
final class InputActivityMonitor {

    struct Activity: Equatable {
        var microphone = false
        var camera = false

        var isActive: Bool { microphone || camera }
    }

    private(set) var activity = Activity()

    private var onChange: ((Activity) -> Void)?
    /// Devices that belong to this app and must not count as somebody listening.
    private var ignoredDevices: () -> Set<AudioObjectID> = { [] }
    private var listeners: [(AudioObjectID, AudioObjectPropertyAddress)] = []
    private var cameraObservation: NSKeyValueObservation?
    private var pollTask: Task<Void, Never>?

    func start(ignoring ignoredDevices: @escaping () -> Set<AudioObjectID> = { [] },
               onChange: @escaping (Activity) -> Void) {
        stop()
        self.onChange = onChange
        self.ignoredDevices = ignoredDevices
        observeMicrophone()
        observeCamera()
        update()
    }

    func stop() {
        for (object, address) in listeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(object, &address, nil) { _, _ in }
        }
        listeners.removeAll()
        cameraObservation?.invalidate()
        cameraObservation = nil
        pollTask?.cancel()
        pollTask = nil
        onChange = nil
    }

    // MARK: - Microphone

    /// The input side of every audio device, plus the default input in case devices come and go.
    private func observeMicrophone() {
        // Core Audio delivers the change on its own queue; a poll alongside it keeps the state right
        // when a device appears or disappears while something is recording.
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.update()
            }
        }
    }

    private func isMicrophoneRunning() -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                             &address, 0, nil, &size) == noErr else { return false }
        var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                         &address, 0, nil, &size, &devices) == noErr else { return false }

        let ignored = ignoredDevices()
        for device in devices where !ignored.contains(device) && hasInput(device) {
            var running = UInt32(0)
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            var runningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            guard AudioObjectGetPropertyData(device, &runningAddress, 0, nil, &runningSize, &running) == noErr else { continue }
            if running != 0 { return true }
        }
        return false
    }

    private func hasInput(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration,
                                                 mScope: kAudioDevicePropertyScopeInput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr, size > 0 else { return false }

        let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { buffer.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, buffer) == noErr else { return false }

        let list = UnsafeMutableAudioBufferListPointer(buffer.assumingMemoryBound(to: AudioBufferList.self))
        return list.contains { $0.mNumberChannels > 0 }
    }

    // MARK: - Camera

    private func observeCamera() {
        // AVFoundation publishes this per device; the default video device covers the built-in and
        // whatever is plugged in as the current one.
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        cameraObservation = device.observe(\.isInUseByAnotherApplication, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.update() }
        }
    }

    private func isCameraRunning() -> Bool {
        AVCaptureDevice.default(for: .video)?.isInUseByAnotherApplication ?? false
    }

    // MARK: - State

    private func update() {
        let current = Activity(microphone: isMicrophoneRunning(), camera: isCameraRunning())
        guard current != activity else { return }
        activity = current
        onChange?(current)
    }
}
