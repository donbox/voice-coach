import Testing
import Foundation
import AVFoundation
@testable import VoiceCoach

/// Tests for RecordingService session lifecycle.
///
/// The crash this guards against: AVCaptureSession was deallocated while
/// startRunning() was still in-flight on the sessionQueue, causing a
/// dispatch_group_leave crash in CMCapture's BWGraph. The fix is a deinit
/// that synchronously drains the sessionQueue before releasing the session.
///
/// Note: these tests run without camera hardware, so startRunning() returns
/// quickly. The tests still exercise the deinit code path and confirm the
/// contract: releasing a RecordingService is always safe, regardless of
/// whether stopSession() was called first.
@MainActor
struct RecordingServiceTests {

    // MARK: - Exact crash reproduction

    /// Reproduces the user-reported crash sequence:
    ///   1. Open recording view → startSession()
    ///   2. Cancel (service released without stopSession())
    ///   3. Open again → new service created → startSession()
    ///   4. Cancel again
    /// Without the deinit fix, this races the capture graph teardown.
    @Test func rapidCancelAndRetryDoesNotCrash() async throws {
        for _ in 0..<3 {
            let service = RecordingService()
            service.startSession()
            // Release immediately without calling stopSession() — the crash path.
        }
        // Allow the sessionQueues of released services to fully drain.
        try await Task.sleep(for: .milliseconds(300))
    }

    /// Verifies the deinit stops the session: after the service is released,
    /// the captured session object must not be running.
    @Test func sessionIsNotRunningAfterRelease() async throws {
        let capturedSession: AVCaptureSession
        var service: RecordingService? = RecordingService()
        capturedSession = service!.captureSession
        service!.startSession()

        // Release without calling stopSession() — the cancel scenario.
        // deinit must block (via sessionQueue.sync) until startRunning/stopRunning
        // finish, then stop the session, before the reference is dropped.
        service = nil

        #expect(!capturedSession.isRunning)
    }

    // MARK: - Basic lifecycle

    @Test func createAndReleaseWithNoCallsDoesNotCrash() {
        _ = RecordingService()
    }

    @Test func startThenExplicitStopThenReleaseDoesNotCrash() async throws {
        let service = RecordingService()
        service.startSession()
        service.stopSession()
        try await Task.sleep(for: .milliseconds(100))
    }

    @Test func sessionNotRunningAfterExplicitStop() async throws {
        let service = RecordingService()
        let session = service.captureSession
        service.startSession()
        service.stopSession()
        // stopSession() is async on sessionQueue, so wait for it to drain.
        try await Task.sleep(for: .milliseconds(100))
        #expect(!session.isRunning)
    }

    // MARK: - Repeated cycles

    @Test func multipleStartStopCyclesOnSameServiceDoNotCrash() async throws {
        let service = RecordingService()
        for _ in 0..<5 {
            service.startSession()
            service.stopSession()
        }
        try await Task.sleep(for: .milliseconds(200))
    }

    @Test func multipleServicesCreatedAndReleasedDoNotCrash() async throws {
        var services: [RecordingService] = []
        for _ in 0..<5 {
            let s = RecordingService()
            s.startSession()
            services.append(s)
        }
        // Release all at once.
        services.removeAll()
        try await Task.sleep(for: .milliseconds(300))
    }
}
