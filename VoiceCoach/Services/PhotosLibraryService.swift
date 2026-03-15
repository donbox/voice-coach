import Foundation
import Photos
import AVFoundation
import os.lock

final class PhotosLibraryService: Sendable {
    static let shared = PhotosLibraryService()

    private init() {}

    // MARK: - Authorization

    func requestWriteAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    // MARK: - Save to Photos

    /// Saves the video at `fileURL` to the Photos library, optionally into a named album.
    /// Returns the PHAsset local identifier on success.
    func saveVideo(at fileURL: URL, albumName: String?) async throws -> String {
        guard await requestWriteAccess() else {
            throw PhotosLibraryError.accessDenied
        }

        var placeholderID: String?

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            placeholderID = request?.placeholderForCreatedAsset?.localIdentifier
        }

        guard let assetID = placeholderID else {
            throw PhotosLibraryError.saveFailed
        }

        let trimmedAlbum = albumName?.trimmingCharacters(in: .whitespaces)
        if let trimmedAlbum, !trimmedAlbum.isEmpty {
            // Best-effort album addition — don't fail the save if album add fails
            try? await addAsset(assetID, toAlbumNamed: trimmedAlbum)
        }

        return assetID
    }

    private func addAsset(_ assetID: String, toAlbumNamed albumName: String) async throws {
        let album = try fetchOrCreateAlbum(named: albumName)

        try await PHPhotoLibrary.shared().performChanges {
            guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) else {
                return
            }
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
            albumChangeRequest.addAssets(assets)
        }
    }

    private func fetchOrCreateAlbum(named name: String) throws -> PHAssetCollection {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", name)
        if let existing = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: options
        ).firstObject {
            return existing
        }

        var placeholderID: String?
        try PHPhotoLibrary.shared().performChangesAndWait {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholderID = request.placeholderForCreatedAssetCollection.localIdentifier
        }

        guard let placeholderID,
              let collection = PHAssetCollection.fetchAssetCollections(
                  withLocalIdentifiers: [placeholderID], options: nil
              ).firstObject else {
            throw PhotosLibraryError.albumCreationFailed
        }

        return collection
    }

    // MARK: - Fetch from Photos

    /// Checks if a Photos asset still exists.
    func assetExists(_ identifier: String) -> Bool {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return result.count > 0
    }

    /// Fetches a playable AVPlayerItem for the given asset identifier.
    func playerItem(for identifier: String) async throws -> AVPlayerItem {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier], options: nil
        ).firstObject else {
            throw PhotosLibraryError.assetNotFound
        }

        let resumeGuard = OSAllocatedUnfairLock(initialState: false)

        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.version = .current

            PHImageManager.default().requestPlayerItem(
                forVideo: asset,
                options: options
            ) { playerItem, info in
                // PHImageManager may invoke the handler more than once;
                // guard with a lock to ensure single continuation resume.
                let alreadyResumed = resumeGuard.withLock { wasResumed -> Bool in
                    if wasResumed { return true }
                    wasResumed = true
                    return false
                }
                guard !alreadyResumed else { return }

                let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let error = info?[PHImageErrorKey] as? Error

                if cancelled {
                    continuation.resume(throwing: PhotosLibraryError.requestCancelled)
                } else if let error {
                    continuation.resume(throwing: error)
                } else if let playerItem {
                    continuation.resume(returning: playerItem)
                } else {
                    continuation.resume(throwing: PhotosLibraryError.assetNotFound)
                }
            }
        }
    }

    // MARK: - Delete

    /// Requests deletion of a Photos asset. The system will prompt the user.
    /// Returns true if deletion succeeded, false if the user denied or asset was already gone.
    func deleteAsset(_ identifier: String) async -> Bool {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier], options: nil
        ).firstObject else {
            return true // Already gone
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([asset] as NSFastEnumeration)
            }
            return true
        } catch {
            return false
        }
    }
}

enum PhotosLibraryError: LocalizedError {
    case accessDenied
    case saveFailed
    case assetNotFound
    case albumCreationFailed
    case requestCancelled

    var errorDescription: String? {
        switch self {
        case .accessDenied: "Photo library access was denied. Please grant access in Settings."
        case .saveFailed: "Failed to save video to the photo library."
        case .assetNotFound: "The video could not be found in your photo library. It may have been deleted."
        case .albumCreationFailed: "Failed to create the Photos album."
        case .requestCancelled: "The request was cancelled."
        }
    }
}
