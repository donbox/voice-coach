import SwiftData

@MainActor
enum PreviewSampleData {
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Exercise.self, Attempt.self, Playlist.self,
            configurations: config
        )

        // Seed some sample data
        let exercise1 = Exercise(
            title: "Lip Trills",
            category: "Warmup",
            courseSession: "Session 1",
            demoVideoRelativePath: "demos/sample.mov"
        )

        let exercise2 = Exercise(
            title: "Breath Support",
            category: "Fundamentals",
            courseSession: "Session 1",
            demoVideoRelativePath: "demos/sample.mov"
        )

        let exercise3 = Exercise(
            title: "Vocal Sirens",
            category: "Range",
            courseSession: "Session 2",
            demoVideoRelativePath: "demos/sample.mov"
        )

        container.mainContext.insert(exercise1)
        container.mainContext.insert(exercise2)
        container.mainContext.insert(exercise3)

        // Add some sample attempts
        let attempt1 = Attempt(videoRelativePath: "attempts/sample1.mov", exercise: exercise1)
        attempt1.durationSeconds = 45
        container.mainContext.insert(attempt1)

        let attempt2 = Attempt(videoRelativePath: "attempts/sample2.mov", exercise: exercise1)
        attempt2.durationSeconds = 52
        container.mainContext.insert(attempt2)

        let attempt3 = Attempt(videoRelativePath: "attempts/sample3.mov", exercise: exercise2)
        attempt3.durationSeconds = 30
        container.mainContext.insert(attempt3)

        // Add a sample playlist
        let playlist = Playlist(name: "Morning Warmup", exercises: [exercise1, exercise3])
        container.mainContext.insert(playlist)

        return container
    }()
}
