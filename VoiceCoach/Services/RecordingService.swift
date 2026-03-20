@preconcurrency import AVFoundation
import AVFAudio
import UIKit

@MainActor
@Observable
final class RecordingService: NSObject {
    var isRecording = false
    var error: Error?
    var usingFrontCamera = false

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
        let position: AVCaptureDevice.Position = usingFrontCamera ? .front : .back
        let preferredCameraID = StorageSettings.preferredCameraID
        let preferredMicID = StorageSettings.preferredMicrophoneID
        let echoCancellation = StorageSettings.echoCancellationEnabled

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    RecordingService.configureAudioSession(
                        echoCancellation: echoCancellation,
                        preferredMicrophoneID: preferredMicID
                    )
                    try RecordingService.configureSession(
                        captureSession,
                        movieOutput: movieOutput,
                        position: position,
                        preferredCameraID: preferredCameraID,
                        preferredMicrophoneID: preferredMicID
                    )
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func flipCamera() async throws {
        usingFrontCamera.toggle()
        let captureSession = self.captureSession
        // Flip always uses position-based selection, ignoring any preferred device.
        let position: AVCaptureDevice.Position = usingFrontCamera ? .front : .back

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    // Remove existing video input
                    for input in captureSession.inputs {
                        if let deviceInput = input as? AVCaptureDeviceInput,
                           deviceInput.device.hasMediaType(.video) {
                            captureSession.removeInput(deviceInput)
                        }
                    }
                    captureSession.beginConfiguration()
                    defer { captureSession.commitConfiguration() }

                    guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
                            ?? AVCaptureDevice.default(for: .video) else {
                        throw RecordingError.cameraUnavailable
                    }
                    let videoInput = try AVCaptureDeviceInput(device: camera)
                    guard captureSession.canAddInput(videoInput) else {
                        throw RecordingError.sessionConfigurationFailed
                    }
                    captureSession.addInput(videoInput)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Configures AVAudioSession for echo cancellation and preferred mic.
    /// Returns true if configuration succeeded.
    @discardableResult
    private nonisolated static func configureAudioSession(
        echoCancellation: Bool,
        preferredMicrophoneID: String? = nil
    ) -> Bool {
        let session = AVAudioSession.sharedInstance()
        let options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP]
        do {
            if echoCancellation {
                // voiceChat mode enables the system's acoustic echo cancellation
                // and forces mono input, eliminating stereo channel delay from webcams.
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: options)
            } else {
                try session.setCategory(.playAndRecord, mode: .videoRecording, options: options)
            }

            // Select preferred input by matching port UID
            if let micID = preferredMicrophoneID,
               let inputs = session.availableInputs,
               let preferred = inputs.first(where: { $0.uid == micID }) {
                try session.setPreferredInput(preferred)
            }

            // Force mono input to prevent stereo channel timing skew from webcam mics.
            try session.setPreferredInputNumberOfChannels(1)
            try session.setActive(true)
            return true
        } catch {
            print("[RecordingService] Failed to configure audio session: \(error.localizedDescription)")
            return false
        }
    }

    private nonisolated static func configureSession(
        _ captureSession: AVCaptureSession,
        movieOutput: AVCaptureMovieFileOutput,
        position: AVCaptureDevice.Position = .back,
        preferredCameraID: String? = nil,
        preferredMicrophoneID: String? = nil
    ) throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.sessionPreset = .high

        // Camera: prefer user-selected device, then position-based, then any available.
        let camera: AVCaptureDevice? = {
            if let id = preferredCameraID,
               let device = AVCaptureDevice(uniqueID: id),
               device.hasMediaType(.video) {
                return device
            }
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
                ?? AVCaptureDevice.default(for: .video)
        }()
        guard let camera else {
            throw RecordingError.cameraUnavailable
        }
        let videoInput = try AVCaptureDeviceInput(device: camera)
        guard captureSession.canAddInput(videoInput) else {
            throw RecordingError.sessionConfigurationFailed
        }
        captureSession.addInput(videoInput)

        // Microphone: prefer user-selected device, then system default.
        let mic: AVCaptureDevice? = {
            if let id = preferredMicrophoneID,
               let device = AVCaptureDevice(uniqueID: id),
               device.hasMediaType(.audio) {
                return device
            }
            return AVCaptureDevice.default(for: .audio)
        }()
        guard let mic else {
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

        // Force mono audio on Mac Catalyst to prevent stereo channel timing skew.
        #if targetEnvironment(macCatalyst)
        if let audioConnection = movieOutput.connection(with: .audio) {
            movieOutput.setOutputSettings(
                [AVNumberOfChannelsKey: 1],
                for: audioConnection
            )
        }
        #endif
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
        let output = movieOutput
        startWatchdogTask = Task { @MainActor in
            // Allow slower capture graph startup before surfacing failure.
            try? await Task.sleep(for: .seconds(4))
            if Task.isCancelled { return }
            // Bail if a new recording has started or this one was cancelled.
            guard self.outputURL == url else { return }
            let recording = await withCheckedContinuation { continuation in
                sessionQueue.async { continuation.resume(returning: output.isRecording) }
            }
            if isRecording && !recording {
                isRecording = false
                error = RecordingError.recordingFailedToStart
            }
        }

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
        // Clear outputURL to invalidate this recording's identity — any delegate
        // callbacks that arrive after this point will see a URL mismatch and be ignored,
        // even if a new recording has already started.
        outputURL = nil
        onRecordingFinished = nil
        isRecording = false
        let output = movieOutput
        // Unconditionally stop — covers the race where startRecording was
        // queued on sessionQueue but hasn't executed yet.
        sessionQueue.async {
            output.stopRecording()
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
            // If this recording was cancelled or superseded while startup was in-flight,
            // its URL will no longer match — stop it immediately.
            if fileURL != outputURL {
                let output = movieOutput
                sessionQueue.async { output.stopRecording() }
            }
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
            // If this recording was cancelled or superseded, its URL will no longer
            // match outputURL — discard the callback entirely.
            guard outputFileURL == self.outputURL else { return }
            if let error {
                self.error = error
            } else {
                self.onRecordingFinished?(outputFileURL)
                self.onRecordingFinished = nil
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
