import SwiftUI
@preconcurrency import AVFoundation
#if targetEnvironment(macCatalyst)
import CoreAudio
#endif

/// Lightweight wrapper so cameras and mics share the same Picker shape.
private struct AudioDeviceInfo: Identifiable {
    let id: String          // uniqueID or portUID
    let name: String
}

struct SettingsView: View {
    @State private var storageMode: AttemptStorageMode = StorageSettings.mode
    @State private var albumName: String = StorageSettings.photosAlbumName
    @State private var preferredCameraID: String = StorageSettings.preferredCameraID ?? ""
    @State private var preferredMicrophoneID: String = StorageSettings.preferredMicrophoneID ?? ""
    @State private var echoCancellation: Bool = StorageSettings.echoCancellationEnabled
    @State private var cameras: [AVCaptureDevice] = []
    @State private var microphones: [AudioDeviceInfo] = []

    var body: some View {
        Form {
            Section {
                Picker("Save Attempts To", selection: $storageMode) {
                    ForEach(AttemptStorageMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }

                Text(storageMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if storageMode == .photosAlbum {
                    TextField("Album Name", text: $albumName)
                    if albumName.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("Album name is required. Videos will save to Camera Roll if left empty.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            } header: {
                Text("Video Storage")
            } footer: {
                Text("This setting applies to new recordings only. Existing attempts are not moved.")
            }

            Section {
                Picker("Camera", selection: $preferredCameraID) {
                    Text("Default").tag("")
                    ForEach(cameras, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }

                Picker("Microphone", selection: $preferredMicrophoneID) {
                    Text("Default").tag("")
                    ForEach(microphones) { mic in
                        Text(mic.name).tag(mic.id)
                    }
                }
            } header: {
                Text("Recording Devices")
            } footer: {
                Text("Choose which camera and microphone to use when recording attempts.")
            }

            Section {
                Toggle("Echo Cancellation", isOn: $echoCancellation)
            } header: {
                Text("Audio")
            } footer: {
                Text("Reduces echo and feedback when your microphone picks up speaker output. Recommended for Mac webcams.")
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            refreshDevices()
        }
        .onChange(of: storageMode) { _, newValue in
            StorageSettings.mode = newValue
        }
        .onChange(of: albumName) { _, newValue in
            StorageSettings.photosAlbumName = newValue
        }
        .onChange(of: preferredCameraID) { _, newValue in
            StorageSettings.preferredCameraID = newValue.isEmpty ? nil : newValue
        }
        .onChange(of: preferredMicrophoneID) { _, newValue in
            StorageSettings.preferredMicrophoneID = newValue.isEmpty ? nil : newValue
        }
        .onChange(of: echoCancellation) { _, newValue in
            StorageSettings.echoCancellationEnabled = newValue
        }
    }

    private func refreshDevices() {
        var cameraTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .external]
        #if !targetEnvironment(macCatalyst)
        cameraTypes += [.builtInTrueDepthCamera, .builtInUltraWideCamera, .builtInTelephotoCamera]
        #endif
        let cameraDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: cameraTypes,
            mediaType: .video,
            position: .unspecified
        )
        cameras = cameraDiscovery.devices

        // Enumerate audio input devices from multiple sources to catch
        // webcam mics, USB interfaces, and built-in mics.
        var mics: [AudioDeviceInfo] = []
        var seenNames = Set<String>()

        #if targetEnvironment(macCatalyst)
        // CoreAudio reliably finds all audio input devices on Mac,
        // including webcam mics that AVCaptureDevice misses.
        for device in coreAudioInputDevices() {
            mics.append(device)
            seenNames.insert(device.name)
        }
        #endif

        // AVCaptureDevice.DiscoverySession — finds devices visible to the
        // capture pipeline.  Use mediaType: nil so webcams that provide
        // both video and audio are included.
        let micDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: nil,
            position: .unspecified
        )
        for device in micDiscovery.devices where device.hasMediaType(.audio) {
            guard !seenNames.contains(device.localizedName) else { continue }
            mics.append(AudioDeviceInfo(id: device.uniqueID, name: device.localizedName))
            seenNames.insert(device.localizedName)
        }

        // AVAudioSession inputs — catches aggregate/system devices.
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord)
        if let inputs = audioSession.availableInputs {
            for input in inputs where !seenNames.contains(input.portName) {
                mics.append(AudioDeviceInfo(id: input.uid, name: input.portName))
                seenNames.insert(input.portName)
            }
        }
        microphones = mics

        // Clear stale selections if saved device is no longer available
        if !preferredCameraID.isEmpty && !cameras.contains(where: { $0.uniqueID == preferredCameraID }) {
            preferredCameraID = ""
            StorageSettings.preferredCameraID = nil
        }
        if !preferredMicrophoneID.isEmpty && !microphones.contains(where: { $0.id == preferredMicrophoneID }) {
            preferredMicrophoneID = ""
            StorageSettings.preferredMicrophoneID = nil
        }
    }
}

#if targetEnvironment(macCatalyst)
private func coreAudioInputDevices() -> [AudioDeviceInfo] {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
    ) == noErr, size > 0 else { return [] }

    let count = Int(size) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
    guard AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs
    ) == noErr else { return [] }

    var results: [AudioDeviceInfo] = []
    for id in deviceIDs {
        // Only include devices with input channels.
        var streamAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var streamSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &streamAddr, 0, nil, &streamSize) == noErr,
              streamSize > 0 else { continue }
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(streamSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &streamAddr, 0, nil, &streamSize, raw) == noErr else { continue }
        let abl = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        let channels = abl.reduce(0) { $0 + Int($1.mNumberChannels) }
        guard channels > 0 else { continue }

        // Device name
        var nameAddr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, &name) == noErr else { continue }

        // Device UID
        var uidAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(id, &uidAddr, 0, nil, &uidSize, &uid) == noErr else { continue }

        results.append(AudioDeviceInfo(id: uid as String, name: name as String))
    }
    return results
}
#endif

#Preview {
    NavigationStack {
        SettingsView()
    }
}
