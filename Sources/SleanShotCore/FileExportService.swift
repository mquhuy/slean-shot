import Foundation

public protocol FileExportService: Sendable {
    @MainActor func saveImageData(_ data: Data)
    @MainActor func saveFile(_ url: URL, suggestedName: String)
    @MainActor func deleteTemporaryFile(_ url: URL)
}

public extension FileExportService {
    // Default no-ops so screenshot-only mocks need not implement recording export.
    @MainActor func saveFile(_ url: URL, suggestedName: String) {}
    @MainActor func deleteTemporaryFile(_ url: URL) {}
}
