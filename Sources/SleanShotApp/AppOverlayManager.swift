import AppKit
import SwiftUI
import SleanShotCore

@MainActor
public final class AppOverlayManager: OverlayManaging {
    private var windows: [UUID: NSWindow] = [:]
    
    public init() {}
    
    public func pin(_ item: CaptureItem, actions: OverlayActions) {
        let screen = NSScreen.main
        let screenWidth = screen?.frame.width ?? 1920
        let screenHeight = screen?.frame.height ?? 1080
        let layout = OverlayPreviewLayout(screenWidth: screenWidth, screenHeight: screenHeight)
        let previewSize = CGSize(width: layout.previewWidth, height: layout.previewHeight)
        let hostingController = NSHostingController(
            rootView: PinnedOverlayView(item: item, actions: actions, previewSize: previewSize)
        )
        let winWidth = layout.windowWidth
        let winHeight = layout.windowHeight
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: winWidth, height: winHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = hostingController
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false // Shadow is drawn by SwiftUI
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        
        // Position at bottom right, just above the dock area
        if let screen = screen {
            let x = screen.visibleFrame.maxX - winWidth - 20
            let y = screen.visibleFrame.minY + 20
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.orderFront(nil)
        windows[item.id] = window
    }

    public func remove(_ id: UUID) {
        windows[id]?.close()
        windows.removeValue(forKey: id)
    }
}
