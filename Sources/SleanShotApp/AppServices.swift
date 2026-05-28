import AppKit
import Combine
import Foundation
import SleanShotCore

@MainActor
protocol AlertPresenting: AnyObject {
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

@MainActor
final class AppServices: ObservableObject {
    private let alertPresenter: AlertPresenting

    init(alertPresenter: AlertPresenting = NSAlertPresenter()) {
        self.alertPresenter = alertPresenter
    }

    func perform(_ command: SleanShotCommand) {
        alertPresenter.show(message: command.unavailableMessage)
    }

    func quit() {
        NSApp.terminate(nil)
    }
}

@MainActor
final class AppClipboardService: ClipboardService {
    nonisolated func copyImageData(_ data: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .png)
    }
}

@MainActor
final class PlaceholderOverlayManager: OverlayManaging {
    func pin(_ item: CaptureItem) {
        // Real AppKit overlay windows are added in a later slice.
    }
}

struct DummyPermissionManager: PermissionManaging {
    var hasScreenCaptureAccess: Bool { true }
    func requestScreenCaptureAccess() async -> Bool { true }
}

struct DummyCaptureEngine: CaptureEngine {
    func captureFullScreen() async throws -> Data { Data() }
}
