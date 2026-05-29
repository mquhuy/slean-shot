import Foundation

public protocol FileExportService: Sendable {
    @MainActor func saveImageData(_ data: Data)
}
