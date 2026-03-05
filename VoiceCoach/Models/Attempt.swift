import Foundation
import SwiftData

@Model
final class Attempt {
    var id: UUID
    var recordedAt: Date

    /// Relative path from the app's Documents/VoiceCoachMedia directory.
    var videoRelativePath: String

    /// Duration in seconds, written after recording finishes.
    var durationSeconds: Double?

    /// Optional user notes.
    var notes: String?

    /// Star rating 1–5; 0 means unrated.
    var rating: Int = 0

    var exercise: Exercise?

    init(
        videoRelativePath: String,
        exercise: Exercise
    ) {
        self.id = UUID()
        self.recordedAt = Date()
        self.videoRelativePath = videoRelativePath
        self.exercise = exercise
    }
}
