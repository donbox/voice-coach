import Foundation

final class VideoStorageService: Sendable {
    static let shared = VideoStorageService()

    private let baseDirectoryName = "VoiceCoachMedia"

    private var baseDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appending(path: baseDirectoryName)
    }

    private var demosDirectory: URL {
        baseDirectory.appending(path: "demos")
    }

    private var attemptsDirectory: URL {
        baseDirectory.appending(path: "attempts")
    }

    private init() {
        ensureDirectoriesExist()
    }

    private func ensureDirectoriesExist() {
        let fm = FileManager.default
        for dir in [demosDirectory, attemptsDirectory] {
            if !fm.fileExists(atPath: dir.path()) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    /// Copies an imported video into the demos directory.
    /// Returns the relative path from baseDirectory.
    func importDemoVideo(from sourceURL: URL) throws -> String {
        let filename = UUID().uuidString + "." + sourceURL.pathExtension
        let relativePath = "demos/\(filename)"
        let destination = baseDirectory.appending(path: relativePath)

        // sourceURL may be a security-scoped resource from file importer
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return relativePath
    }

    /// Copies an existing video into the attempts directory.
    /// Returns the relative path from baseDirectory.
    func importAttemptVideo(from sourceURL: URL) throws -> String {
        let filename = UUID().uuidString + "." + (sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension)
        let relativePath = "attempts/\(filename)"
        let destination = baseDirectory.appending(path: relativePath)

        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return relativePath
    }

    /// Returns a new file URL for recording an attempt.
    func newAttemptFileURL() -> (absoluteURL: URL, relativePath: String) {
        let filename = UUID().uuidString + ".mov"
        let relativePath = "attempts/\(filename)"
        let absoluteURL = baseDirectory.appending(path: relativePath)
        return (absoluteURL, relativePath)
    }

    /// Resolves a relative path to an absolute file URL.
    func resolveURL(for relativePath: String) -> URL {
        baseDirectory.appending(path: relativePath)
    }

    /// Deletes the video file at the given relative path.
    func deleteVideo(at relativePath: String) throws {
        let url = resolveURL(for: relativePath)
        if FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
