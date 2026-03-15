import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Query(sort: \Exercise.createdAt, order: .reverse) private var exercises: [Exercise]
    @Environment(\.modelContext) private var modelContext
    @State private var showingCreation = false

    var body: some View {
        Group {
            if exercises.isEmpty {
                ContentUnavailableView(
                    "No Exercises",
                    systemImage: "music.note",
                    description: Text("Tap + to add your first exercise.")
                )
            } else {
                List {
                    ForEach(exercises) { exercise in
                        NavigationLink(value: exercise) {
                            ExerciseRowView(exercise: exercise)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteExercise(exercise)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteExercise(exercise)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("tenK")
        .navigationDestination(for: Exercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreation = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreation) {
            ExerciseCreationView(suggestedTitle: "Exercise \(exercises.count + 1)")
        }
    }

    private func deleteExercise(_ exercise: Exercise) {
        // Clean up demo video
        try? VideoStorageService.shared.deleteVideo(at: exercise.demoVideoRelativePath)
        // Clean up all attempt videos
        for attempt in exercise.attempts {
            try? VideoStorageService.shared.deleteVideo(at: attempt.videoRelativePath)
        }
        modelContext.delete(exercise)
    }
}

#Preview {
    NavigationStack {
        ExerciseListView()
    }
    .modelContainer(PreviewSampleData.container)
}
