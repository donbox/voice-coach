import SwiftUI

struct SettingsView: View {
    @State private var storageMode: AttemptStorageMode = StorageSettings.mode
    @State private var albumName: String = StorageSettings.photosAlbumName

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
        }
        .navigationTitle("Settings")
        .onChange(of: storageMode) { _, newValue in
            StorageSettings.mode = newValue
        }
        .onChange(of: albumName) { _, newValue in
            StorageSettings.photosAlbumName = newValue
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
