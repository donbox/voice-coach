import SwiftUI

struct RecordingView: View {
    let exercise: Exercise
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = RecordingService()
    @State private var configurationError: Error?
    @State private var isSavingToPhotos = false
    @State private var photosSaveError: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewRepresentable(session: recorder.captureSession)
                .ignoresSafeArea()

            VStack {
                // Top bar
                HStack {
                    Button {
                        recorder.cancelRecording()
                        recorder.stopSession()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text(exercise.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        Task {
                            try? await recorder.flipCamera()
                        }
                    } label: {
                        Image(systemName: "camera.rotate.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    .disabled(recorder.isRecording)
                }
                .padding()

                Spacer()

                if isSavingToPhotos {
                    ProgressView("Saving to Photos…")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .padding(.bottom, 20)
                }

                // Record button
                Button {
                    if recorder.isRecording {
                        recorder.stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 72, height: 72)

                        if recorder.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.red)
                                .frame(width: 28, height: 28)
                        } else {
                            Circle()
                                .fill(.red)
                                .frame(width: 60, height: 60)
                        }
                    }
                }
                .disabled(isSavingToPhotos)
                .padding(.bottom, 40)
            }

            if let displayError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text(displayError.localizedDescription)
                        .multilineTextAlignment(.center)
                    Button("Dismiss") {
                        recorder.stopSession()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .foregroundStyle(.white)
                .padding()
            }
        }
        .task {
            do {
                try await recorder.configure()
                recorder.startSession()
            } catch {
                configurationError = error
            }
        }
        .alert("Photos Save Failed", isPresented: Binding(
            get: { photosSaveError != nil },
            set: { if !$0 { photosSaveError = nil } }
        )) {
            Button("OK") {
                photosSaveError = nil
                dismiss()
            }
        } message: {
            Text("Video was saved locally instead.\n\(photosSaveError ?? "")")
        }
    }

    private var displayError: Error? {
        configurationError ?? recorder.error
    }

    private func startRecording() {
        let (url, relativePath) = VideoStorageService.shared.newAttemptFileURL()
        recorder.startRecording(to: url) { _ in
            if StorageSettings.savesToPhotos {
                saveToPhotos(localURL: url, localRelativePath: relativePath)
            } else {
                let attempt = Attempt(videoRelativePath: relativePath, exercise: exercise)
                modelContext.insert(attempt)
                recorder.stopSession()
                dismiss()
            }
        }
    }

    private func saveToPhotos(localURL: URL, localRelativePath: String) {
        isSavingToPhotos = true
        Task { @MainActor in
            do {
                let assetID = try await PhotosLibraryService.shared.saveVideo(
                    at: localURL,
                    albumName: StorageSettings.albumNameForSaving
                )
                // Remove the local copy since it's now in Photos
                try? VideoStorageService.shared.deleteVideo(at: localRelativePath)

                let attempt = Attempt(
                    videoRelativePath: "",
                    exercise: exercise,
                    photosAssetIdentifier: assetID
                )
                modelContext.insert(attempt)
            } catch {
                // Fallback: keep as local storage but inform the user
                let attempt = Attempt(videoRelativePath: localRelativePath, exercise: exercise)
                modelContext.insert(attempt)
                photosSaveError = error.localizedDescription
            }
            isSavingToPhotos = false
            recorder.stopSession()
            if photosSaveError == nil {
                dismiss()
            }
        }
    }
}
