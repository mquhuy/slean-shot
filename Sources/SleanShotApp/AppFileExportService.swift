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
}
