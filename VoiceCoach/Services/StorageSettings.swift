import Foundation

enum AttemptStorageMode: String, CaseIterable, Identifiable, Sendable {
    case local = "local"
    case photosDefault = "photos_default"
    case photosAlbum = "photos_album"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .local: "App Storage (iCloud)"
        case .photosDefault: "Camera Roll"
        case .photosAlbum: "Photos Album"
        }
    }

    var description: String {
        switch self {
        case .local: "Videos are stored in the app's data and sync via iCloud."
        case .photosDefault: "Videos are saved to your Camera Roll."
        case .photosAlbum: "Videos are saved to a specific Photos album."
        }
    }
}

@MainActor
enum StorageSettings {
    private static let defaults = UserDefaults.standard

    static var mode: AttemptStorageMode {
        get {
            let raw = defaults.string(forKey: "attemptStorageMode") ?? AttemptStorageMode.local.rawValue
            return AttemptStorageMode(rawValue: raw) ?? .local
        }
        set { defaults.set(newValue.rawValue, forKey: "attemptStorageMode") }
    }

    static var photosAlbumName: String {
        get { defaults.string(forKey: "photosAlbumName") ?? "tenK" }
        set { defaults.set(newValue, forKey: "photosAlbumName") }
    }

    static var albumNameForSaving: String? {
        switch mode {
        case .local: nil
        case .photosDefault: nil
        case .photosAlbum: photosAlbumName
        }
    }

    static var savesToPhotos: Bool {
        mode != .local
    }
}
