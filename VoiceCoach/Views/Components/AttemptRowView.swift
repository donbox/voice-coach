import SwiftUI

struct AttemptRowView: View {
    let attempt: Attempt
    var showExerciseTitle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showExerciseTitle, let exercise = attempt.exercise {
                Text(exercise.title)
                    .font(.headline)
            }

            HStack(spacing: 12) {
                Label(attempt.recordedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")

                if let duration = attempt.durationSeconds {
                    Label(formatDuration(duration), systemImage: "timer")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let notes = attempt.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
