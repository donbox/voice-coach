import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ExerciseListView()
            }
            .tabItem { Label("Exercises", systemImage: "music.note.list") }

            NavigationStack {
                GlobalFeedView()
            }
            .tabItem { Label("Feed", systemImage: "clock") }

            NavigationStack {
                PlaylistListView()
            }
            .tabItem { Label("Playlists", systemImage: "list.bullet") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
