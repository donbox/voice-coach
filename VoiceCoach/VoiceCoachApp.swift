import SwiftUI
import SwiftData

@main
struct VoiceCoachApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([Exercise.self, Attempt.self, Playlist.self])
        let cloudConfig = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )
        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: cloudConfig
            )
        } catch {
            print("[VoiceCoachApp] CloudKit ModelContainer failed: \(error). Falling back to local store.")
            // Fallback to local-only store if CloudKit is unavailable
            do {
                let localConfig = ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .none
                )
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: localConfig
                )
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
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
