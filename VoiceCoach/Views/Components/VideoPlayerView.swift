import AVKit
import SwiftUI

struct VideoPlayerView: View {
    let relativePath: String
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                Rectangle()
                    .fill(.black)
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }
        }
        .task(id: relativePath) {
            let url = VideoStorageService.shared.resolveURL(for: relativePath)
            let item = AVPlayerItem(url: url)
            // Hop off the main actor so AVPlayer initialization doesn't block UI
            let newPlayer = await Task.detached(priority: .userInitiated) {
                AVPlayer(playerItem: item)
            }.value
            player = newPlayer
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
