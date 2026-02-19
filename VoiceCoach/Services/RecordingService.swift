@preconcurrency import AVFoundation
import UIKit

@MainActor
@Observable
final class RecordingService: NSObject {
    var isRecording = false
    var error: Error?

    private(set) var captureSession = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var outputURL: URL?
    private var onRecordingFinished: ((URL) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.voicecoach.capture-session")

    func configure() async throws {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        if cameraStatus == .notDetermined {
            await AVCaptureDevice.requestAccess(for: .video)
        }
        if micStatus == .notDetermined {
            await AVCaptureDevice.requestAccess(for: .audio)
        }

        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            throw RecordingError.permissionDenied
        }

        let captureSession = self.captureSession
        let movieOutput = self.movieOutput

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    try RecordingService.configureSession(captureSession, movieOutput: movieOutput)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private nonisolated static func configureSession(
        _ captureSession: AVCaptureSession,
        movieOutput: AVCaptureMovieFileOutput
    ) throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.sessionPreset = .high

        // Front camera for self-recording
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw RecordingError.cameraUnavailable
        }
        let videoInput = try AVCaptureDeviceInput(device: camera)
        guard captureSession.canAddInput(videoInput) else {
            throw RecordingError.sessionConfigurationFailed
        }
        captureSession.addInput(videoInput)

        // Microphone
        guard let mic = AVCaptureDevice.default(for: .audio) else {
            throw RecordingError.microphoneUnavailable
        }
        let audioInput = try AVCaptureDeviceInput(device: mic)
        guard captureSession.canAddInput(audioInput) else {
            throw RecordingError.sessionConfigurationFailed
        }
        captureSession.addInput(audioInput)

        // Movie output
        guard captureSession.canAddOutput(movieOutput) else {
            throw RecordingError.sessionConfigurationFailed
        }
        captureSession.addOutput(movieOutput)
    }

    func startSession() {
        let session = captureSession
        sessionQueue.async {
            session.startRunning()
        }
    }

    func stopSession() {
        let session = captureSession
        sessionQueue.async {
            session.stopRunning()
        }
    }

    func startRecording(to url: URL, onFinished: @escaping (URL) -> Void) {
        outputURL = url
        onRecordingFinished = onFinished
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
    }

    func stopRecording() {
        movieOutput.stopRecording()
    }
}

extension RecordingService: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            self.isRecording = false
            if let error {
                self.error = error
            } else {
                self.onRecordingFinished?(outputFileURL)
            }
        }
    }
}

enum RecordingError: LocalizedError {
    case permissionDenied
    case cameraUnavailable
    case microphoneUnavailable
    case sessionConfigurationFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Camera or microphone access was denied."
        case .cameraUnavailable: "No camera is available."
        case .microphoneUnavailable: "No microphone is available."
        case .sessionConfigurationFailed: "Failed to configure the recording session."
        }
    }
}
