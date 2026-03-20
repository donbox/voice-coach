import AVKit
import SwiftUI

struct VideoPlayerView: View {
    let relativePath: String
    var photosAssetIdentifier: String? = nil
    var autoPlay: Bool = false
    var isActive: Bool = true
    var onDeleteAttempt: (() -> Void)? = nil
    var onRelinkVideo: (() -> Void)? = nil
    @State private var player: AVPlayer?
    @State private var videoUnavailable = false
    @State private var lastLoadedID: String?

    var body: some View {
        Group {
            if videoUnavailable {
                Rectangle()
                    .fill(.black)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "video.slash")
                                .font(.largeTitle)
                            Text("Video Unavailable")
                                .font(.headline)
                            Text("This video may have been deleted or is not accessible.")
                                .font(.caption)
                                .multilineTextAlignment(.center)

                            if onDeleteAttempt != nil || onRelinkVideo != nil {
                                HStack(spacing: 12) {
                                    if let onRelinkVideo {
                                        Button {
                                            onRelinkVideo()
                                        } label: {
                                            Label("Re-link Video", systemImage: "link")
                                                .font(.subheadline)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    if let onDeleteAttempt {
                                        Button(role: .destructive) {
                                            onDeleteAttempt()
                                        } label: {
                                            Label("Delete Attempt", systemImage: "trash")
                                                .font(.subheadline)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                                .padding(.top, 4)
                            }
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
            let taskID = "\(relativePath)|\(photosAssetIdentifier ?? "")"
            let isNewVideo = taskID != lastLoadedID
            lastLoadedID = taskID

            // Only reload the player when the video actually changed —
            // not on tab-switch re-appearance.
            guard isNewVideo else { return }

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
        .onChange(of: isActive) { _, active in
            if !active { player?.pause() }
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
