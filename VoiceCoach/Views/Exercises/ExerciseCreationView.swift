import SwiftUI
import PhotosUI

struct ExerciseCreationView: View {
    let suggestedTitle: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool

    @State private var title = ""
    @State private var category = ""
    @State private var courseSession = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedVideoURL: URL?
    @State private var selectedAssetIdentifier: String?
    @State private var isLoading = false
    @State private var importError: String?

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && (selectedVideoURL != nil || selectedAssetIdentifier != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                        .focused($titleFocused)
                    TextField("Category (optional)", text: $category)
                    TextField("Course Session (optional)", text: $courseSession)
                }

                Section("Instructor Video") {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Loading video…")
                                .foregroundStyle(.secondary)
                        }
                    } else if selectedAssetIdentifier != nil {
                        Label("Selected from Photos", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if let url = selectedVideoURL {
                        Label(url.lastPathComponent, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    let hasVideo = selectedVideoURL != nil
                    PhotosPicker(
                        selection: $pickerItem,
                        matching: .videos,
                        photoLibrary: .shared()
                    ) {
                        Label(
                            hasVideo ? "Change Video" : "Choose Video",
                            systemImage: "photo.on.rectangle"
                        )
                    }
                }

                if let importError {
                    Section {
                        Text(importError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExercise() }
                        .disabled(!canSave || isLoading)
                }
            }
            .onAppear {
                title = suggestedTitle
                titleFocused = true
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                loadVideo(from: newItem)
            }
        }
    }

    private func loadVideo(from item: PhotosPickerItem) {
        isLoading = true
        importError = nil
        selectedVideoURL = nil
        selectedAssetIdentifier = nil

        // Prefer keeping the Photos asset identifier so the demo video
        // roams across devices via iCloud Photos.
        if let assetID = item.itemIdentifier,
           PhotosLibraryService.shared.assetExists(assetID) {
            selectedAssetIdentifier = assetID
            isLoading = false
            return
        }

        // Fallback: transfer the file locally
        Task {
            do {
                guard let transferred = try await item.loadTransferable(type: VideoTransferable.self) else {
                    importError = "Could not load the selected video."
                    isLoading = false
                    return
                }
                selectedVideoURL = transferred.url
            } catch {
                importError = "Failed to load video: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func saveExercise() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedCategory = category.trimmingCharacters(in: .whitespaces)
        let trimmedSession = courseSession.trimmingCharacters(in: .whitespaces)

        if let assetID = selectedAssetIdentifier {
            // Photos-backed demo video — roams via iCloud Photos
            let exercise = Exercise(
                title: trimmedTitle,
                category: trimmedCategory,
                courseSession: trimmedSession,
                demoPhotosAssetIdentifier: assetID
            )
            modelContext.insert(exercise)
            dismiss()
        } else if let sourceURL = selectedVideoURL {
            // Fallback: copy file locally
            do {
                let relativePath = try VideoStorageService.shared.importDemoVideo(from: sourceURL)
                let exercise = Exercise(
                    title: trimmedTitle,
                    category: trimmedCategory,
                    courseSession: trimmedSession,
                    demoVideoRelativePath: relativePath
                )
                modelContext.insert(exercise)
                dismiss()
            } catch {
                importError = "Failed to import video: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    ExerciseCreationView(suggestedTitle: "Exercise 4")
        .modelContainer(PreviewSampleData.container)
}
