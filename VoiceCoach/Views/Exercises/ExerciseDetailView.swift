import SwiftUI
import AVKit

struct ExerciseDetailView: View {
    @Bindable var exercise: Exercise
    @Environment(\.modelContext) private var modelContext
    @State private var showingRecording = false
    @State private var sortNewestFirst = true
    @State private var selectedAttempt: Attempt?

    private var sortedAttempts: [Attempt] {
        exercise.attempts.sorted { a, b in
            sortNewestFirst ? a.recordedAt > b.recordedAt : a.recordedAt < b.recordedAt
        }
    }

    var body: some View {
        List {
            Section {
                VideoPlayerView(relativePath: exercise.demoVideoRelativePath)
                    .aspectRatio(16/9, contentMode: .fit)
                    .listRowInsets(EdgeInsets())
            } header: {
                Text("Instructor Demo")
            }

            Section {
                if sortedAttempts.isEmpty {
                    ContentUnavailableView(
                        "No Attempts Yet",
                        systemImage: "video.badge.plus",
                        description: Text("Record your first attempt.")
                    )
                } else {
                    ForEach(sortedAttempts) { attempt in
                        Button {
                            selectedAttempt = attempt
                        } label: {
                            HStack {
                                Text(attempt.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                Spacer()
                                if let duration = attempt.durationSeconds {
                                    Text(formatDuration(duration))
                                        .foregroundStyle(.secondary)
                                }
                                Image(systemName: "play.circle")
                                    .foregroundStyle(.tint)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteAttempt(attempt)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteAttempt(attempt)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("My Attempts (\(exercise.attempts.count))")
                    Spacer()
                    SortOrderPicker(newestFirst: $sortNewestFirst)
                }
            }
        }
        .navigationTitle(exercise.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingRecording = true
                } label: {
                    Label("Record", systemImage: "record.circle")
                }
            }
        }
        .fullScreenCover(isPresented: $showingRecording) {
            RecordingView(exercise: exercise)
        }
        .sheet(item: $selectedAttempt) { attempt in
            AttemptPlayerSheet(attempt: attempt)
        }
    }

    private func deleteAttempt(_ attempt: Attempt) {
        try? VideoStorageService.shared.deleteVideo(at: attempt.videoRelativePath)
        modelContext.delete(attempt)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct AttemptPlayerSheet: View {
    let attempt: Attempt
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VideoPlayerView(relativePath: attempt.videoRelativePath)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(attempt.recordedAt.formatted(date: .abbreviated, time: .shortened))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
