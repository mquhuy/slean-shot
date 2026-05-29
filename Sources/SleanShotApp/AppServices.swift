import AppKit
import Combine
import Foundation
import OSLog
import SleanShotCore

@MainActor
protocol AlertPresenting: AnyObject, Sendable {
    func show(message: String)
}

@MainActor
final class NSAlertPresenter: AlertPresenting {
    func show(message: String) {
        let alert = NSAlert()
        alert.messageText = "SleanShot"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private let logger = Logger(subsystem: "com.huy.SleanShot", category: "AppServices")

@MainActor
final class AppServices: ObservableObject {
    private let alertPresenter: AlertPresenting
    private let coordinator: AppCoordinator

    init(
        alertPresenter: AlertPresenting = NSAlertPresenter(),
        coordinator: AppCoordinator? = nil
    ) {
        self.alertPresenter = alertPresenter
        if let coordinator = coordinator {
            self.coordinator = coordinator
        } else {
            let settings = SettingsStore()
            let clipboard = AppClipboardService(alertPresenter: alertPresenter)
            let overlays = AppOverlayManager()
            let fileExport = AppFileExportService(alertPresenter: alertPresenter)
            let permissions = AppPermissionManager()
            let capture = AppCaptureEngine()
            let areaSelection = AppAreaSelectionService()
            let annotationEditor = AppAnnotationEditor(
                alertPresenter: alertPresenter,
                clipboardService: clipboard
            )

            self.coordinator = AppCoordinator(
                settings: settings,
                clipboard: clipboard,
                overlays: overlays,
                fileExport: fileExport,
                permissionManager: permissions,
                captureEngine: capture,
                areaSelection: areaSelection,
                annotationEditor: annotationEditor
            )
        }
    }

    func perform(_ command: SleanShotCommand) {
        logger.info("perform command=\(command)")
        Task {
            do {
                try await coordinator.handle(command)
                logger.info("command completed=\(command)")
            } catch CaptureError.permissionDenied {
                logger.info("command permissionDenied=\(command)")
                alertPresenter.show(message: "Screen Recording permission is required. Please grant it in System Settings.\n\nIf you just granted it, you MUST restart SleanShot for it to take effect.")
            } catch CaptureError.permissionNeedsRestart {
                logger.info("command permissionNeedsRestart=\(command)")
                alertPresenter.show(message: "Screen Recording permission was just granted. Please restart SleanShot to enable screen capture.")
            } catch CaptureError.captureFailed(let reason) {
                logger.info("command captureFailed=\(command) reason=\(reason)")
                alertPresenter.show(message: reason)
            } catch {
                logger.info("command unknownError=\(command) error=\(error)")
                alertPresenter.show(message: "An unknown error occurred.")
            }
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }
}

final class AppClipboardService: Sendable, ClipboardService {
    private let alertPresenter: AlertPresenting

    init(alertPresenter: AlertPresenting) {
        self.alertPresenter = alertPresenter
    }

    func copyImageData(_ data: Data) {
        Task { @MainActor [alertPresenter] in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            if !pasteboard.setData(data, forType: .png) {
                alertPresenter.show(message: "Copy failed. Please try again.")
            }
        }
    }
}
