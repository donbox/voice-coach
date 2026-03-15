import Foundation
import SwiftData

@Model
final class Attempt {
    var id: UUID
    var recordedAt: Date

    /// Relative path from the app's Documents/VoiceCoachMedia directory.
    /// Empty string when the video is stored in Photos only.
    var videoRelativePath: String

    /// PHAsset local identifier when the video is stored in the Photos library.
    /// Nil means the video uses local app storage only.
    var photosAssetIdentifier: String?

    /// Duration in seconds, written after recording finishes.
    var durationSeconds: Double?

    /// Optional user notes.
    var notes: String?

    /// Star rating 1–5; 0 means unrated.
    var rating: Int = 0

    var exercise: Exercise?

    /// True when the video is backed by a Photos library asset.
    var isPhotosBackedVideo: Bool {
        photosAssetIdentifier?.isEmpty == false
    }

    init(
        videoRelativePath: String,
        exercise: Exercise,
        photosAssetIdentifier: String? = nil
    ) {
        self.id = UUID()
        self.recordedAt = Date()
        self.videoRelativePath = videoRelativePath
        self.photosAssetIdentifier = photosAssetIdentifier
        self.exercise = exercise
    }
}
