import SwiftUI
import SwiftData

struct PlaylistListView: View {
    @Query(sort: \Playlist.createdAt, order: .reverse) private var playlists: [Playlist]
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewPlaylist = false
    @State private var newPlaylistName = ""

    var body: some View {
        Group {
            if playlists.isEmpty {
                ContentUnavailableView(
                    "No Playlists",
                    systemImage: "list.bullet",
                    description: Text("Create a playlist to organize your daily routine.")
                )
            } else {
                List {
                    ForEach(playlists) { playlist in
                        NavigationLink(value: playlist) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlist.name)
                                    .font(.headline)
                                Text("\(playlist.exercises.count) exercises")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .onDelete(perform: deletePlaylists)
                }
            }
        }
        .navigationTitle("Playlists")
        .navigationDestination(for: Playlist.self) { playlist in
            PlaylistDetailView(playlist: playlist)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newPlaylistName = "Playlist \(playlists.count + 1)"
                    showingNewPlaylist = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Playlist", isPresented: $showingNewPlaylist) {
            TextField("Playlist name", text: $newPlaylistName)
            Button("Cancel", role: .cancel) {
                newPlaylistName = ""
            }
            Button("Create") {
                createPlaylist()
            }
        }
    }

    private func createPlaylist() {
        let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let playlist = Playlist(name: name)
        modelContext.insert(playlist)
        newPlaylistName = ""
    }

    private func deletePlaylists(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(playlists[index])
        }
    }
}

#Preview {
    NavigationStack {
        PlaylistListView()
    }
    .modelContainer(PreviewSampleData.container)
}
