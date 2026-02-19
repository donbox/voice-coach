import Foundation
import SwiftData

@Model
final class Playlist {
    var id: UUID
    var name: String
    var createdAt: Date
    var exercises: [Exercise]

    init(name: String, exercises: [Exercise] = []) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.exercises = exercises
    }
}
