import SwiftUI
import AVKit

struct ExerciseDetailView: View {
    @Bindable var exercise: Exercise
    @Environment(\.modelContext) private var modelContext
    @State private var showingRecording = false
    @State private var sortNewestFirst = true
    // Index-based selection: avoids stale-closure bugs with Mac Catalyst UIKeyCommands.
    @State private var selectedAttemptIndex: Int? = nil

    private var sortedAttempts: [Attempt] {
        exercise.attempts.sorted { a, b in
            sortNewestFirst ? a.recordedAt > b.recordedAt : a.recordedAt < b.recordedAt
        }
    }

    private var selectedAttempt: Attempt? {
        guard let idx = selectedAttemptIndex,
              sortedAttempts.indices.contains(idx) else { return nil }
        return sortedAttempts[idx]
    }

    var body: some View {
        VStack(spacing: 0) {
            videoArea
            Divider()
            attemptList
        }
        .navigationTitle(exercise.title)
        .fullScreenCover(isPresented: $showingRecording) {
            RecordingView(exercise: exercise)
        }
        .onChange(of: sortNewestFirst) { _, _ in selectedAttemptIndex = nil }
        // Provide exercise actions to the Exercise menu.
        .focusedSceneValue(\.exerciseActions, ExerciseActions(
            newAttempt: { showingRecording = true },
            previousAttempt: { selectedAttemptIndex? -= 1 },
            nextAttempt: { selectedAttemptIndex? += 1 },
            rateAttempt: { rating in
                guard let idx = selectedAttemptIndex,
                      sortedAttempts.indices.contains(idx) else { return }
                sortedAttempts[idx].rating = rating
            },
            canGoPrev: (selectedAttemptIndex ?? 0) > 0,
            canGoNext: selectedAttemptIndex.map { $0 < sortedAttempts.count - 1 } ?? false,
            hasAttempt: selectedAttemptIndex != nil
        ))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if selectedAttemptIndex != nil {
                    // Shortcuts are duplicated on the Commands menu items above.
                    // Mac menu bar fires first when the Commands item is enabled;
                    // these UIKeyCommands fire as fallback when FocusedSceneValue
                    // is unreliable (e.g. AVPlayerViewController holds firstResponder).
                    Button {
                        selectedAttemptIndex? -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(selectedAttemptIndex == 0)
                    .keyboardShortcut(",", modifiers: [])

                    if let idx = selectedAttemptIndex {
                        Text("\(idx + 1) / \(sortedAttempts.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Button {
                        selectedAttemptIndex? += 1
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(selectedAttemptIndex == sortedAttempts.count - 1)
                    .keyboardShortcut(".", modifiers: [])
                }

                Button {
                    showingRecording = true
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    // MARK: - Video area

    @ViewBuilder
    private var videoArea: some View {
        let relativePath = selectedAttempt?.videoRelativePath ?? exercise.demoVideoRelativePath
        let photosID = selectedAttempt?.photosAssetIdentifier
        ZStack(alignment: .bottom) {
            VideoPlayerView(relativePath: relativePath, photosAssetIdentifier: photosID, autoPlay: selectedAttempt != nil)
                .aspectRatio(16/9, contentMode: .fit)
                .frame(maxWidth: .infinity)

            if let idx = selectedAttemptIndex, sortedAttempts.indices.contains(idx) {
                let attempt = sortedAttempts[idx]
                HStack {
                    Button {
                        selectedAttemptIndex = nil
                    } label: {
                        Label("Demo", systemImage: "arrow.uturn.backward")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.regularMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])

                    Spacer()

                    StarRatingView(rating: Binding(
                        get: { attempt.rating },
                        set: { attempt.rating = $0 }
                    ))
                    .font(.title3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                }
                .padding(10)
            }
        }
    }

    // MARK: - Attempt list

    private var attemptList: some View {
        List {
            Button {
                showingRecording = true
            } label: {
                Label("New Attempt", systemImage: "plus.circle.fill")
                    .foregroundStyle(.tint)
            }

            if !sortedAttempts.isEmpty {
                Section {
                    ForEach(sortedAttempts.indices, id: \.self) { idx in
                        let attempt = sortedAttempts[idx]
                        let isSelected = selectedAttemptIndex == idx
                        Button {
                            selectedAttemptIndex = isSelected ? nil : idx
                        } label: {
                            HStack(spacing: 8) {
                                Text(attempt.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                Spacer()
                                StarRatingView(rating: Binding(
                                    get: { attempt.rating },
                                    set: { attempt.rating = $0 }
                                ))
                                .font(.subheadline)
                                if let duration = attempt.durationSeconds {
                                    Text(formatDuration(duration))
                                        .foregroundStyle(.secondary)
                                }
                                Image(systemName: isSelected ? "stop.circle.fill" : "play.circle")
                                    .foregroundStyle(.tint)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        // Make rows reachable via Tab key.
                        .focusable()
                        .listRowBackground(isSelected ? Color.accentColor.opacity(0.12) : nil)
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
                } header: {
                    HStack {
                        Text("My Attempts (\(exercise.attempts.count))")
                        Spacer()
                        SortOrderPicker(newestFirst: $sortNewestFirst)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func deleteAttempt(_ attempt: Attempt) {
        if selectedAttempt?.id == attempt.id { selectedAttemptIndex = nil }
        if attempt.isPhotosBackedVideo {
            Task { @MainActor in
                if let assetID = attempt.photosAssetIdentifier {
                    _ = await PhotosLibraryService.shared.deleteAsset(assetID)
                }
                modelContext.delete(attempt)
            }
        } else {
            try? VideoStorageService.shared.deleteVideo(at: attempt.videoRelativePath)
            modelContext.delete(attempt)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
