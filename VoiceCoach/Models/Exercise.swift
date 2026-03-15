import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID = UUID()
    var title: String = ""
    var category: String = ""
    var courseSession: String = ""
    var createdAt: Date = Date()

    /// Relative path from the app's Documents/VoiceCoachMedia directory.
    var demoVideoRelativePath: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Attempt.exercise)
    var attempts: [Attempt] = []

    @Relationship(inverse: \Playlist.exercises)
    var playlists: [Playlist] = []

    init(
        title: String,
        category: String = "",
        courseSession: String = "",
        demoVideoRelativePath: String
    ) {
        self.id = UUID()
        self.title = title
        self.category = category
        self.courseSession = courseSession
        self.demoVideoRelativePath = demoVideoRelativePath
        self.createdAt = Date()
        self.attempts = []
        self.playlists = []
    }
}
