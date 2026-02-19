import CoreTransferable
import UniformTypeIdentifiers

/// Bridges PhotosPickerItem → a temporary file URL for video assets.
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tmp = FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: tmp)
            return VideoTransferable(url: tmp)
        }
    }
}
