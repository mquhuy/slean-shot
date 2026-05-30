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
    private let recordingControl = RecordingControlPanel()
    private let recordingBorder = RecordingBorderWindow()

    @Published private(set) var isRecording = false

    init(
        alertPresenter: AlertPresenting = NSAlertPresenter(),
        coordinator: AppCoordinator? = nil
    ) {
        self.alertPresenter = alertPresenter
        if let coordinator = coordinator {
            self.coordinator = coordinator
        } else {
            let settings = UserDefaultsSettingsStore()
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
            let recording = AppRecordingEngine()

            self.coordinator = AppCoordinator(
                settings: settings,
                clipboard: clipboard,
                overlays: overlays,
                fileExport: fileExport,
                permissionManager: permissions,
                captureEngine: capture,
                areaSelection: areaSelection,
                annotationEditor: annotationEditor,
                recordingEngine: recording
            )
        }
    }

    func perform(_ command: SleanShotCommand) {
        logger.info("perform command=\(command)")
        Task {
            do {
                try await coordinator.handle(command)
                logger.info("command completed=\(command)")
                if command.isRecording {
                    let recording = await coordinator.isRecording
                    isRecording = recording
                    if recording {
                        recordingControl.show { [weak self] in
                            self?.stopRecording()
                        }
                        await showRecordingBorderIfEnabled()
                    }
                }
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

    func stopRecording() {
        Task {
            do {
                try await coordinator.stopRecording()
            } catch {
                logger.info("stopRecording error=\(error)")
                alertPresenter.show(message: "Recording failed to save. Please try again.")
            }
            isRecording = false
            recordingControl.hide()
            recordingBorder.hide()
        }
    }

    private func showRecordingBorderIfEnabled() async {
        guard UserDefaults.standard.object(forKey: "showRecordingBorder") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "showRecordingBorder") else {
            return
        }

        let rect: NSRect
        if let area = await coordinator.activeRecordingArea {
            rect = NSRect(x: area.rect.x, y: area.rect.y, width: area.rect.width, height: area.rect.height)
        } else if let screen = NSScreen.main {
            rect = screen.frame
        } else {
            return
        }
        recordingBorder.show(rect: rect)
    }

    func quit() {
        NSApp.terminate(nil)
    }
}

/// Live, `UserDefaults`-backed view of settings so the coordinator reads the
/// current toggle value at capture time (the Settings screen writes the same key
/// via `@AppStorage`). Absent key defaults to enabled.
struct UserDefaultsSettingsStore: SettingsProviding {
    nonisolated(unsafe) private let defaults: UserDefaults
    private let key = "autoCopyScreenshotToClipboard"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var autoCopyScreenshotToClipboard: Bool {
        defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
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

    func copyFileURL(_ url: URL) {
        Task { @MainActor [alertPresenter] in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            if !pasteboard.writeObjects([url as NSURL]) {
                alertPresenter.show(message: "Copy failed. Please try again.")
            }
        }
    }
}
