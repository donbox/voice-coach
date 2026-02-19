import SwiftUI
import UniformTypeIdentifiers

struct ExerciseCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var category = ""
    @State private var courseSession = ""
    @State private var showingFileImporter = false
    @State private var selectedVideoURL: URL?
    @State private var importError: String?

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && selectedVideoURL != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Category (optional)", text: $category)
                    TextField("Course Session (optional)", text: $courseSession)
                }

                Section("Instructor Video") {
                    if let url = selectedVideoURL {
                        Label(url.lastPathComponent, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Button {
                        showingFileImporter = true
                    } label: {
                        Label(
                            selectedVideoURL == nil ? "Choose Video" : "Change Video",
                            systemImage: "doc.badge.plus"
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
                        .disabled(!canSave)
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedVideoURL = urls.first
            importError = nil
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func saveExercise() {
        guard let sourceURL = selectedVideoURL else { return }

        do {
            let relativePath = try VideoStorageService.shared.importDemoVideo(from: sourceURL)
            let exercise = Exercise(
                title: title.trimmingCharacters(in: .whitespaces),
                category: category.trimmingCharacters(in: .whitespaces),
                courseSession: courseSession.trimmingCharacters(in: .whitespaces),
                demoVideoRelativePath: relativePath
            )
            modelContext.insert(exercise)
            dismiss()
        } catch {
            importError = "Failed to import video: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ExerciseCreationView()
        .modelContainer(PreviewSampleData.container)
}
