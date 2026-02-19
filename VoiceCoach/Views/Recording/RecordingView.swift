import SwiftUI

struct RecordingView: View {
    let exercise: Exercise
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = RecordingService()
    @State private var configurationError: Error?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewRepresentable(session: recorder.captureSession)
                .ignoresSafeArea()

            VStack {
                // Top bar
                HStack {
                    Button {
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
                    // Spacer for symmetry
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding()

                Spacer()

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
                .padding(.bottom, 40)
            }

            if let error = configurationError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text(error.localizedDescription)
                        .multilineTextAlignment(.center)
                    Button("Dismiss") { dismiss() }
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
    }

    private func startRecording() {
        let (url, relativePath) = VideoStorageService.shared.newAttemptFileURL()
        recorder.startRecording(to: url) { _ in
            let attempt = Attempt(videoRelativePath: relativePath, exercise: exercise)
            modelContext.insert(attempt)
            recorder.stopSession()
            dismiss()
        }
    }
}
