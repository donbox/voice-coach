import SwiftUI
@preconcurrency import AVFoundation

struct SettingsView: View {
    @State private var storageMode: AttemptStorageMode = StorageSettings.mode
    @State private var albumName: String = StorageSettings.photosAlbumName
    @State private var preferredCameraID: String = StorageSettings.preferredCameraID ?? ""
    @State private var preferredMicrophoneID: String = StorageSettings.preferredMicrophoneID ?? ""
    @State private var echoCancellation: Bool = StorageSettings.echoCancellationEnabled
    @State private var cameras: [AVCaptureDevice] = []
    @State private var microphones: [AVCaptureDevice] = []

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
                    ForEach(microphones, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
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

        let micTypes: [AVCaptureDevice.DeviceType]
        if #available(iOS 17.0, macCatalyst 17.0, *) {
            micTypes = [.microphone, .external]
        } else {
            micTypes = [.builtInMicrophone, .external]
        }
        let micDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: micTypes,
            mediaType: .audio,
            position: .unspecified
        )
        microphones = micDiscovery.devices

        // Clear stale selections if saved device is no longer available
        if !preferredCameraID.isEmpty && !cameras.contains(where: { $0.uniqueID == preferredCameraID }) {
            preferredCameraID = ""
            StorageSettings.preferredCameraID = nil
        }
        if !preferredMicrophoneID.isEmpty && !microphones.contains(where: { $0.uniqueID == preferredMicrophoneID }) {
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
