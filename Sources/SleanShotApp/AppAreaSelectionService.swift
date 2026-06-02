import AppKit
import OSLog
import SwiftUI
import SleanShotCore

private let selectionLogger = Logger(subsystem: "com.huy.SleanShot", category: "AreaSelection")

@MainActor
final class AppAreaSelectionService: AreaSelectionService {
    private var activeWindows: [SelectionOverlayWindow] = []
    private var continuation: UnsafeContinuation<CaptureArea?, Never>?
    private var didFinish = false
    private var selectionGate = SelectionGate()

    func selectArea() async -> CaptureArea? {
        selectionLogger.info("selectArea begin requested")
        guard selectionGate.begin() else {
            selectionLogger.info("selectArea already active; bringing existing window count=\(self.activeWindows.count)")
            bringToFront()
            return nil
        }
        return await withUnsafeContinuation { continuation in
            selectionLogger.info("selectArea continuation stored")
            self.continuation = continuation
            self.didFinish = false
            self.presentSelectionWindow()
        }
    }

    private func presentSelectionWindow() {
        selectionLogger.info("presentSelectionWindow reached")

        let screens = NSScreen.screens
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main ?? screens.first
        guard let screen = targetScreen else {
            finish(nil)
            return
        }

        let display = CaptureDisplay(
            id: screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0,
            frame: CaptureRect(x: screen.frame.origin.x, y: screen.frame.origin.y, width: screen.frame.width, height: screen.frame.height),
            scaleFactor: screen.backingScaleFactor
        )

        let window = SelectionOverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.onCancel = { [weak self] in
            self?.finish(nil)
        }

        let hostingView = CrosshairHostingView(rootView: SelectionOverlayView(display: display) { [weak self] area in
            self?.finish(area)
        })
        hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        activeWindows = [window]
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    private func finish(_ area: CaptureArea?) {
        guard !didFinish else { return }
        didFinish = true
        let c = continuation
        self.continuation = nil
        selectionGate.end()
        let windowsToClose = activeWindows
        activeWindows.removeAll()
        // Close windows synchronously first so ScreenCaptureKit doesn't see
        // the full-screen overlay when captureArea calls SCShareableContent.
        windowsToClose.forEach { $0.orderOut(nil) }
        // Yield one run-loop cycle to let the window server process the removal
        // before capture starts.
        DispatchQueue.main.async {
            c?.resume(returning: area)
        }
    }

    private func bringToFront() {
        activeWindows.forEach { window in
            window.makeKeyAndOrderFront(nil)
        }
    }
}
