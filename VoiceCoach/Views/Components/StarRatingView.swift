import SwiftUI

/// Interactive 1–5 star rating. Tapping the current star clears the rating.
struct StarRatingView: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    rating = (rating == star) ? 0 : star
                } label: {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .foregroundStyle(star <= rating ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Read-only star display (no binding).
struct StarDisplayView: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundStyle(star <= rating ? Color.yellow : Color.secondary)
            }
        }
    }
}
