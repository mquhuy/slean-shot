import Foundation

public enum CaptureItemKind: Equatable {
    case screenshot
    case recording
}

public struct CaptureItem: Equatable, Identifiable {
    public let id: UUID
    public let kind: CaptureItemKind
    public let imageData: Data?
    public let fileURL: URL?
    public let thumbnailData: Data?

    private init(
        id: UUID,
        kind: CaptureItemKind,
        imageData: Data?,
        fileURL: URL?,
        thumbnailData: Data?
    ) {
        self.id = id
        self.kind = kind
        self.imageData = imageData
        self.fileURL = fileURL
        self.thumbnailData = thumbnailData
    }

    public static func screenshot(id: UUID = UUID(), imageData: Data) -> CaptureItem {
        CaptureItem(
            id: id,
            kind: .screenshot,
            imageData: imageData,
            fileURL: nil,
            thumbnailData: nil
        )
    }

    public static func recording(id: UUID = UUID(), fileURL: URL, thumbnailData: Data?) -> CaptureItem {
        CaptureItem(
            id: id,
            kind: .recording,
            imageData: nil,
            fileURL: fileURL,
            thumbnailData: thumbnailData
        )
    }
}
