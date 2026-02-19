import SwiftUI
import SwiftData

@main
struct VoiceCoachApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Exercise.self, Attempt.self, Playlist.self])
    }
}
