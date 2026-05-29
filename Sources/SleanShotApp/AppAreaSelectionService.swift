import AppKit
import SwiftUI
import SleanShotCore

@MainActor
final class AppAreaSelectionService: AreaSelectionService {
    private var activeWindows: [SelectionOverlayWindow] = []
    private var continuation: CheckedContinuation<CaptureArea?, Never>?
    private var didFinish = false
    private var selectionGate = SelectionGate()

    func selectArea() async -> CaptureArea? {
        guard selectionGate.begin() else {
            bringToFront()
            return nil
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.didFinish = false
            self.presentSelectionWindow()
        }
    }

    private func presentSelectionWindow() {
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

        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.onCancel = { [weak self] in
            self?.finish(nil)
        }
        window.contentViewController = NSHostingController(
            rootView: SelectionOverlayView(display: display) { [weak self] area in
                self?.finish(area)
            }
        )

        activeWindows = [window]
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func finish(_ area: CaptureArea?) {
        guard !didFinish else { return }
        didFinish = true
        activeWindows.forEach { $0.close() }
        activeWindows.removeAll()
        let continuation = continuation
        self.continuation = nil
        selectionGate.end()
        continuation?.resume(returning: area)
    }

    private func bringToFront() {
        activeWindows.forEach { window in
            window.makeKeyAndOrderFront(nil)
        }
    }
}
