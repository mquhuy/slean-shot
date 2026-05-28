import AppKit
import SwiftUI
import SleanShotCore

@MainActor
public final class AppOverlayManager: OverlayManaging {
    private var windows: [UUID: NSWindow] = [:]
    
    public init() {}
    
    public func pin(_ item: CaptureItem) {
        let hostingController = NSHostingController(rootView: PinnedOverlayView(item: item, closeAction: { [weak self] in
            self?.close(item.id)
        }))
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 440),
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
        
        // Position at bottom right roughly
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 460
            let y = screenFrame.minY + 50
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.orderFront(nil)
        windows[item.id] = window
    }
    
    private func close(_ id: UUID) {
        windows[id]?.close()
        windows.removeValue(forKey: id)
    }
}
