import AVKit
import SwiftUI

struct VideoPlayerView: View {
    let relativePath: String
    var photosAssetIdentifier: String? = nil
    var autoPlay: Bool = false
    @State private var player: AVPlayer?
    @State private var videoUnavailable = false

    var body: some View {
        Group {
            if videoUnavailable {
                Rectangle()
                    .fill(.black)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "video.slash")
                                .font(.largeTitle)
                            Text("Video Unavailable")
                                .font(.headline)
                            Text("This video may have been deleted or is not accessible.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.secondary)
                        .padding()
                    }
            } else if let player {
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
        .task(id: "\(relativePath)|\(photosAssetIdentifier ?? "")") {
            videoUnavailable = false
            player?.pause()
            player = nil

            if let assetID = photosAssetIdentifier {
                do {
                    let item = try await PhotosLibraryService.shared.playerItem(for: assetID)
                    let newPlayer = AVPlayer(playerItem: item)
                    player = newPlayer
                    if autoPlay { newPlayer.play() }
                } catch {
                    videoUnavailable = true
                }
            } else {
                let url = VideoStorageService.shared.resolveURL(for: relativePath)
                guard FileManager.default.fileExists(atPath: url.path()) else {
                    videoUnavailable = true
                    return
                }
                let newPlayer = AVPlayer(url: url)
                player = newPlayer
                if autoPlay { newPlayer.play() }
            }
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
