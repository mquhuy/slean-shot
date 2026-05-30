import AppKit
import Foundation
import UniformTypeIdentifiers
import SleanShotCore

@MainActor
final class AppFileExportService: FileExportService {
    private let alertPresenter: AlertPresenting

    init(alertPresenter: AlertPresenting) {
        self.alertPresenter = alertPresenter
    }

    func saveImageData(_ data: Data) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Screenshot.png"

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            return
        }

        do {
            try data.write(to: url)
        } catch {
            alertPresenter.show(message: "Save failed. Please try again.")
        }
    }

    func saveFile(_ sourceURL: URL, suggestedName: String) {
        let panel = NSSavePanel()
        if let type = UTType(filenameExtension: sourceURL.pathExtension) {
            panel.allowedContentTypes = [type]
        }
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName

        let response = panel.runModal()
        guard response == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            alertPresenter.show(message: "Save failed. Please try again.")
        }
    }

    func deleteTemporaryFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
