import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ExerciseListView()
            }
            .tabItem { Label("Exercises", systemImage: "music.note.list") }
            .tag(0)

            NavigationStack {
                GlobalFeedView()
            }
            .tabItem { Label("Feed", systemImage: "clock") }
            .tag(1)

            NavigationStack {
                PlaylistListView()
            }
            .tabItem { Label("Playlists", systemImage: "list.bullet") }
            .tag(2)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(3)
        }
        .focusedSceneValue(\.appNavigation, AppNavigationActions(switchTab: { selectedTab = $0 }))
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
