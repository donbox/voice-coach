import SwiftUI
@preconcurrency import AVFoundation

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

        // Use AVAudioSession for mic enumeration — AVCaptureDevice.DiscoverySession
        // doesn't reliably list external/USB mics on Mac Catalyst.
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord)
        if let inputs = audioSession.availableInputs {
            microphones = inputs.map { AudioDeviceInfo(id: $0.uid, name: $0.portName) }
        } else {
            microphones = []
        }

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

#Preview {
    NavigationStack {
        SettingsView()
    }
}
