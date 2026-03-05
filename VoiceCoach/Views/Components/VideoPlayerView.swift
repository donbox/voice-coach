import AVKit
import SwiftUI
import UIKit

struct VideoPlayerView: View {
    let relativePath: String
    var autoPlay: Bool = false
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                PlayerViewControllerRepresentable(player: player)
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
            let newPlayer = AVPlayer(url: url)
            player = newPlayer
            if autoPlay { newPlayer.play() }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

/// AVPlayerViewController wrapped for SwiftUI — renders correctly on Mac Catalyst
/// and all iOS/iPadOS layouts including inside List rows.
private struct PlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = true
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        vc.player = player
    }
}
