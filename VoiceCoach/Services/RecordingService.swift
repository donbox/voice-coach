@preconcurrency import AVFoundation
import UIKit

@MainActor
@Observable
final class RecordingService: NSObject {
    var isRecording = false
    var error: Error?

    // nonisolated(unsafe) so that deinit (which is non-isolated) can stop the session.
    // All off-main-actor access is serialized through sessionQueue.
    nonisolated(unsafe) private(set) var captureSession = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var outputURL: URL?
    private var onRecordingFinished: ((URL) -> Void)?
    private var startWatchdogTask: Task<Void, Never>?

    private let sessionQueue = DispatchQueue(label: "com.voicecoach.capture-session")

    deinit {
        // Block until any pending startRunning/stopRunning on the sessionQueue has
        // finished. Without this, the AVCaptureSession can be deallocated while the
        // capture graph's startRunning is still in-flight, causing a crash in the
        // BWGraph dispatch_group_leave completion block.
        let session = captureSession
        sessionQueue.sync {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

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

        // Prefer front camera for self-recording; fall back to any camera (Mac Catalyst).
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video) else {
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
        error = nil
        isRecording = true
        startWatchdogTask?.cancel()
        startWatchdogTask = Task { @MainActor in
            // Allow slower capture graph startup before surfacing failure.
            try? await Task.sleep(for: .seconds(4))
            if Task.isCancelled { return }
            if isRecording && !movieOutput.isRecording {
                isRecording = false
                error = RecordingError.recordingFailedToStart
            }
        }

        let output = movieOutput
        sessionQueue.async {
            output.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() {
        startWatchdogTask?.cancel()
        startWatchdogTask = nil
        let output = movieOutput
        sessionQueue.async {
            output.stopRecording()
        }
    }

    func cancelRecording() {
        startWatchdogTask?.cancel()
        startWatchdogTask = nil
        onRecordingFinished = nil
        isRecording = false
        let output = movieOutput
        sessionQueue.async {
            if output.isRecording {
                output.stopRecording()
            }
        }
    }
}

extension RecordingService: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        Task { @MainActor in
            startWatchdogTask?.cancel()
            startWatchdogTask = nil
        }
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            startWatchdogTask?.cancel()
            startWatchdogTask = nil
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
    case recordingFailedToStart

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Camera or microphone access was denied."
        case .cameraUnavailable: "No camera is available."
        case .microphoneUnavailable: "No microphone is available."
        case .sessionConfigurationFailed: "Failed to configure the recording session."
        case .recordingFailedToStart: "Recording failed to start. The camera may not be available."
        }
    }
}
