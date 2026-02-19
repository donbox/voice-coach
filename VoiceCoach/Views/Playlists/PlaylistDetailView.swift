import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    @Bindable var playlist: Playlist
    @State private var showingExercisePicker = false

    var body: some View {
        List {
            if playlist.exercises.isEmpty {
                ContentUnavailableView(
                    "Empty Playlist",
                    systemImage: "music.note",
                    description: Text("Add exercises to build your routine.")
                )
            } else {
                ForEach(playlist.exercises) { exercise in
                    NavigationLink(value: exercise) {
                        ExerciseRowView(exercise: exercise)
                    }
                }
                .onDelete(perform: removeExercises)
                .onMove(perform: moveExercises)
            }
        }
        .navigationTitle(playlist.name)
        .navigationDestination(for: Exercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingExercisePicker = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView(playlist: playlist)
        }
    }

    private func removeExercises(at offsets: IndexSet) {
        playlist.exercises.remove(atOffsets: offsets)
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        playlist.exercises.move(fromOffsets: source, toOffset: destination)
    }
}

struct ExercisePickerView: View {
    let playlist: Playlist
    @Query(sort: \Exercise.title) private var allExercises: [Exercise]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(allExercises) { exercise in
                let isInPlaylist = playlist.exercises.contains(where: { $0.id == exercise.id })
                Button {
                    if !isInPlaylist {
                        playlist.exercises.append(exercise)
                    }
                } label: {
                    HStack {
                        Text(exercise.title)
                        Spacer()
                        if isInPlaylist {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .disabled(isInPlaylist)
            }
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
