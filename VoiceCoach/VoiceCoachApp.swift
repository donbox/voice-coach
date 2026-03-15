import SwiftUI
import SwiftData

@main
struct VoiceCoachApp: App {
    let modelContainer: ModelContainer

    init() {
        let cloudConfig = ModelConfiguration(
            cloudKitDatabase: .automatic
        )
        do {
            modelContainer = try ModelContainer(
                for: Exercise.self, Attempt.self, Playlist.self,
                configurations: cloudConfig
            )
        } catch {
            // Fallback to local-only store if CloudKit is unavailable
            let localConfig = ModelConfiguration()
            modelContainer = try! ModelContainer(
                for: Exercise.self, Attempt.self, Playlist.self,
                configurations: localConfig
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .commands { VoiceCoachCommands() }
    }
}
