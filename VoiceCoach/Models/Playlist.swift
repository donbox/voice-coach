import Foundation
import SwiftData

@Model
final class Playlist {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var exercises: [Exercise]?

    init(name: String, exercises: [Exercise]? = nil) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.exercises = exercises
    }
}
