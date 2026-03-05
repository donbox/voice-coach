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
                ForEach(Array(playlist.exercises.enumerated()), id: \.element.id) { index, exercise in
                    NavigationLink {
                        PlaylistExerciseDetailView(exercises: playlist.exercises, startIndex: index)
                    } label: {
                        ExerciseRowView(exercise: exercise)
                    }
                }
                .onDelete(perform: removeExercises)
                .onMove(perform: moveExercises)
            }
        }
        .navigationTitle(playlist.name)
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

// MARK: - Playlist-mode exercise navigator

struct PlaylistExerciseDetailView: View {
    let exercises: [Exercise]
    @State private var currentIndex: Int

    init(exercises: [Exercise], startIndex: Int) {
        self.exercises = exercises
        self._currentIndex = State(initialValue: startIndex)
    }

    private var current: Exercise { exercises[currentIndex] }

    var body: some View {
        ExerciseDetailView(exercise: current)
            .id(current.id)  // reset ExerciseDetailView state when exercise changes
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        currentIndex -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentIndex == 0)
                    .keyboardShortcut("[", modifiers: [])

                    Text("\(currentIndex + 1) / \(exercises.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Button {
                        currentIndex += 1
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentIndex == exercises.count - 1)
                    .keyboardShortcut("]", modifiers: [])
                }
            }
    }
}

// MARK: - Exercise picker sheet

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
