import SwiftUI

struct SortOrderPicker: View {
    @Binding var newestFirst: Bool

    var body: some View {
        Menu {
            Button {
                newestFirst = true
            } label: {
                Label("Newest First", systemImage: newestFirst ? "checkmark" : "")
            }
            Button {
                newestFirst = false
            } label: {
                Label("Oldest First", systemImage: newestFirst ? "" : "checkmark")
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.caption)
        }
    }
}
