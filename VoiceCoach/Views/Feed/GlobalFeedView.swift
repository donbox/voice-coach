import SwiftUI
import SwiftData
import AVKit

struct GlobalFeedView: View {
    @Query(sort: \Attempt.recordedAt, order: .reverse) private var attempts: [Attempt]
    @Environment(\.modelContext) private var modelContext
    @State private var currentIndex: Int = 0

    var body: some View {
        Group {
            if attempts.isEmpty {
                ContentUnavailableView(
                    "No Recordings Yet",
                    systemImage: "video.slash",
                    description: Text("Record an attempt on any exercise to see it here.")
                )
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(attempts.enumerated()), id: \.element.id) { index, attempt in
                        FeedVideoPage(
                            attempt: attempt,
                            isActive: index == currentIndex,
                            onDelete: { deleteAttempt(attempt) }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }
        }
        .navigationTitle("tenK")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !attempts.isEmpty {
                    Button {
                        if currentIndex > 0 { currentIndex -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentIndex == 0)
                    .keyboardShortcut(",", modifiers: [])

                    Button {
                        if currentIndex < attempts.count - 1 { currentIndex += 1 }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentIndex == attempts.count - 1)
                    .keyboardShortcut(".", modifiers: [])
                }
            }
        }
    }

    private func deleteAttempt(_ attempt: Attempt) {
        if attempt.isPhotosBackedVideo {
            Task { @MainActor in
                if let assetID = attempt.photosAssetIdentifier {
                    _ = await PhotosLibraryService.shared.deleteAsset(assetID)
                }
                modelContext.delete(attempt)
            }
        } else {
            try? VideoStorageService.shared.deleteVideo(at: attempt.videoRelativePath)
            modelContext.delete(attempt)
        }
    }
}

struct FeedVideoPage: View {
    @Bindable var attempt: Attempt
    let isActive: Bool
    let onDelete: () -> Void
    @State private var player: AVPlayer?
    @State private var videoUnavailable = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if videoUnavailable {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                        Text("Video Unavailable")
                            .font(.headline)
                    }
                    .foregroundStyle(.secondary)
                } else if let player {
                    FeedPlayerRepresentable(player: player)
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                // Overlay
                VStack {
                    // Exercise name + date at top
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if let exercise = attempt.exercise {
                                Text(exercise.title)
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            Text(attempt.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                        }
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2)
                        .padding()

                        Spacer()
                    }
                    .padding(.top, 8)

                    Spacer()

                    // Star rating at bottom left
                    HStack {
                        StarRatingView(rating: $attempt.rating)
                            .font(.title2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.regularMaterial, in: Capsule())
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Attempt", systemImage: "trash")
            }
        }
        .task {
            if let assetID = attempt.photosAssetIdentifier {
                do {
                    let item = try await PhotosLibraryService.shared.playerItem(for: assetID)
                    player = AVPlayer(playerItem: item)
                    if isActive { player?.play() }
                } catch {
                    videoUnavailable = true
                }
            } else {
                let url = VideoStorageService.shared.resolveURL(for: attempt.videoRelativePath)
                guard FileManager.default.fileExists(atPath: url.path()) else {
                    videoUnavailable = true
                    return
                }
                player = AVPlayer(url: url)
                if isActive { player?.play() }
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .onChange(of: isActive) { _, active in
            if active {
                player?.seek(to: .zero)
                player?.play()
            } else {
                player?.pause()
            }
        }
    }
}

/// Uses AVPlayerLayer for full-screen video without playback controls.
struct FeedPlayerRepresentable: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> FeedPlayerUIView {
        let view = FeedPlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: FeedPlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

final class FeedPlayerUIView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

#Preview {
    NavigationStack {
        GlobalFeedView()
    }
    .modelContainer(PreviewSampleData.container)
}
