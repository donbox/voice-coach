import Testing
import SwiftData
import Foundation
@testable import VoiceCoach

@MainActor
struct ModelTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Exercise.self, Attempt.self, Playlist.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Exercise

    @Test func createAndFetchExercise() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let exercise = Exercise(
            title: "Scale Exercise",
            category: "Scales",
            courseSession: "Week 1",
            demoVideoRelativePath: "demos/test.mov"
        )
        context.insert(exercise)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        #expect(fetched.count == 1)
        #expect(fetched[0].title == "Scale Exercise")
        #expect(fetched[0].category == "Scales")
        #expect(fetched[0].courseSession == "Week 1")
        #expect(fetched[0].demoVideoRelativePath == "demos/test.mov")
    }

    @Test func exerciseStartsWithNoAttempts() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let exercise = Exercise(title: "Warmup", demoVideoRelativePath: "demos/warmup.mov")
        context.insert(exercise)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        #expect((fetched[0].attempts ?? []).isEmpty)
    }

    @Test func deleteExerciseCascadesToAttempts() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let exercise = Exercise(title: "Test Exercise", demoVideoRelativePath: "demos/test.mov")
        context.insert(exercise)

        let attempt = Attempt(videoRelativePath: "attempts/test.mov", exercise: exercise)
        var attempts = exercise.attempts ?? []
        attempts.append(attempt)
        exercise.attempts = attempts
        context.insert(attempt)
        try context.save()

        let attemptsBefore = try context.fetch(FetchDescriptor<Attempt>())
        #expect(attemptsBefore.count == 1)

        context.delete(exercise)
        try context.save()

        let attemptsAfter = try context.fetch(FetchDescriptor<Attempt>())
        #expect(attemptsAfter.count == 0)
    }

    @Test func multipleAttemptsPerExercise() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let exercise = Exercise(title: "Test", demoVideoRelativePath: "demos/test.mov")
        context.insert(exercise)

        for i in 0..<5 {
            let attempt = Attempt(videoRelativePath: "attempts/\(i).mov", exercise: exercise)
            var attempts = exercise.attempts ?? []
            attempts.append(attempt)
            exercise.attempts = attempts
            context.insert(attempt)
        }
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        #expect((fetched[0].attempts ?? []).count == 5)
    }

    @Test func deleteOneAttemptLeavesOthers() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let exercise = Exercise(title: "Test", demoVideoRelativePath: "demos/test.mov")
        context.insert(exercise)

        for i in 0..<3 {
            let attempt = Attempt(videoRelativePath: "attempts/\(i).mov", exercise: exercise)
            var attempts = exercise.attempts ?? []
            attempts.append(attempt)
            exercise.attempts = attempts
            context.insert(attempt)
        }
        try context.save()

        let toDelete = (exercise.attempts ?? [])[0]
        context.delete(toDelete)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        #expect((fetched[0].attempts ?? []).count == 2)
    }

    // MARK: - Attempt

    @Test func attemptHasOptionalFields() {
        let exercise = Exercise(title: "Test", demoVideoRelativePath: "demos/test.mov")
        let attempt = Attempt(videoRelativePath: "attempts/test.mov", exercise: exercise)
        #expect(attempt.notes == nil)
        #expect(attempt.durationSeconds == nil)
    }

    @Test func attemptStoresDuration() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let exercise = Exercise(title: "Test", demoVideoRelativePath: "demos/test.mov")
        context.insert(exercise)

        let attempt = Attempt(videoRelativePath: "attempts/test.mov", exercise: exercise)
        attempt.durationSeconds = 42.5
        context.insert(attempt)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Attempt>())
        #expect(fetched[0].durationSeconds == 42.5)
    }

    // MARK: - Playlist

    @Test func createPlaylistWithExercises() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let exercise1 = Exercise(title: "E1", demoVideoRelativePath: "demos/e1.mov")
        let exercise2 = Exercise(title: "E2", demoVideoRelativePath: "demos/e2.mov")
        context.insert(exercise1)
        context.insert(exercise2)

        let playlist = Playlist(name: "Morning Routine", exercises: [exercise1, exercise2])
        context.insert(playlist)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Playlist>())
        #expect(fetched.count == 1)
        #expect(fetched[0].name == "Morning Routine")
        #expect((fetched[0].exercises ?? []).count == 2)
    }

    @Test func addExerciseToExistingPlaylist() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let exercise = Exercise(title: "Warmup", demoVideoRelativePath: "demos/warmup.mov")
        let playlist = Playlist(name: "Daily Routine")
        context.insert(exercise)
        context.insert(playlist)
        try context.save()

        var list = playlist.exercises ?? []
        list.append(exercise)
        playlist.exercises = list
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Playlist>())
        #expect((fetched[0].exercises ?? []).count == 1)
        #expect((fetched[0].exercises ?? [])[0].title == "Warmup")
    }

    @Test func exerciseCanBelongToMultiplePlaylists() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let exercise = Exercise(title: "Scales", demoVideoRelativePath: "demos/scales.mov")
        let playlist1 = Playlist(name: "Morning")
        let playlist2 = Playlist(name: "Evening")
        context.insert(exercise)
        context.insert(playlist1)
        context.insert(playlist2)

        var list1 = playlist1.exercises ?? []
        list1.append(exercise)
        playlist1.exercises = list1
        var list2 = playlist2.exercises ?? []
        list2.append(exercise)
        playlist2.exercises = list2
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        #expect((fetched[0].playlists ?? []).count == 2)
    }

    @Test func deletePlaylistDoesNotDeleteExercises() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let exercise = Exercise(title: "Warmup", demoVideoRelativePath: "demos/warmup.mov")
        let playlist = Playlist(name: "Routine", exercises: [exercise])
        context.insert(exercise)
        context.insert(playlist)
        try context.save()

        context.delete(playlist)
        try context.save()

        let exercisesAfter = try context.fetch(FetchDescriptor<Exercise>())
        #expect(exercisesAfter.count == 1)
        let playlistsAfter = try context.fetch(FetchDescriptor<Playlist>())
        #expect(playlistsAfter.count == 0)
    }

    @Test func emptyPlaylistHasNoExercises() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let playlist = Playlist(name: "Empty")
        context.insert(playlist)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Playlist>())
        #expect((fetched[0].exercises ?? []).isEmpty)
    }
}
