import SwiftUI

struct ExerciseRowView: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.title)
                .font(.headline)

            HStack(spacing: 12) {
                if !exercise.category.isEmpty {
                    Label(exercise.category, systemImage: "tag")
                }
                if !exercise.courseSession.isEmpty {
                    Label(exercise.courseSession, systemImage: "calendar")
                }
                Label("\(exercise.attempts.count)", systemImage: "video")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
