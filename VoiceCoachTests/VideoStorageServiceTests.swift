import Testing
import Foundation
@testable import VoiceCoach

struct VideoStorageServiceTests {

    @Test func resolveURLContainsExpectedPathComponents() {
        let url = VideoStorageService.shared.resolveURL(for: "demos/test.mov")
        #expect(url.lastPathComponent == "test.mov")
        #expect(url.path().contains("VoiceCoachMedia/demos"))
    }

    @Test func newAttemptFileURLHasMovExtension() {
        let (absoluteURL, relativePath) = VideoStorageService.shared.newAttemptFileURL()
        #expect(absoluteURL.pathExtension == "mov")
        #expect(relativePath.hasPrefix("attempts/"))
        #expect(relativePath.hasSuffix(".mov"))
    }

    @Test func newAttemptFileURLsAreUnique() {
        let (_, path1) = VideoStorageService.shared.newAttemptFileURL()
        let (_, path2) = VideoStorageService.shared.newAttemptFileURL()
        #expect(path1 != path2)
    }

    @Test func absoluteURLMatchesResolvedURL() {
        let (absoluteURL, relativePath) = VideoStorageService.shared.newAttemptFileURL()
        let resolved = VideoStorageService.shared.resolveURL(for: relativePath)
        #expect(absoluteURL == resolved)
    }

    @Test func importDemoVideoCopiesFileToDestination() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension("mov")
        try Data("fake video data".utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let relativePath = try VideoStorageService.shared.importDemoVideo(from: tempURL)
        defer { try? VideoStorageService.shared.deleteVideo(at: relativePath) }

        #expect(relativePath.hasPrefix("demos/"))
        #expect(relativePath.hasSuffix(".mov"))
        let resolvedURL = VideoStorageService.shared.resolveURL(for: relativePath)
        #expect(FileManager.default.fileExists(atPath: resolvedURL.path()))
    }

    @Test func importDemoVideoPreservesFileExtension() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension("mp4")
        try Data("fake video".utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let relativePath = try VideoStorageService.shared.importDemoVideo(from: tempURL)
        defer { try? VideoStorageService.shared.deleteVideo(at: relativePath) }

        #expect(relativePath.hasSuffix(".mp4"))
    }

    @Test func deleteVideoRemovesFile() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension("mov")
        try Data("fake video data".utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let relativePath = try VideoStorageService.shared.importDemoVideo(from: tempURL)
        let resolvedURL = VideoStorageService.shared.resolveURL(for: relativePath)

        try VideoStorageService.shared.deleteVideo(at: relativePath)

        #expect(!FileManager.default.fileExists(atPath: resolvedURL.path()))
    }

    @Test func deleteNonexistentVideoDoesNotThrow() {
        #expect(throws: Never.self) {
            try VideoStorageService.shared.deleteVideo(at: "demos/nonexistent_\(UUID().uuidString).mov")
        }
    }
}
