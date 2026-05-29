import AppKit
import SwiftUI
import SleanShotCore

@MainActor
public final class AppOverlayManager: OverlayManaging {
    private var windows: [UUID: NSWindow] = [:]
    private var orderedIDs: [UUID] = []
    
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
        let staggeredOffset: CGFloat = CGFloat(orderedIDs.count * 40)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: winWidth, height: winHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = hostingController
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        
        if let screen = screen {
            let x = screen.visibleFrame.maxX - winWidth - 20 - staggeredOffset
            let y = screen.visibleFrame.minY + 20 + staggeredOffset
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.orderFront(nil)
        windows[item.id] = window
        orderedIDs.append(item.id)
    }

    public func remove(_ id: UUID) {
        windows[id]?.orderOut(nil)
        windows.removeValue(forKey: id)
        orderedIDs.removeAll { $0 == id }
        relayout()
    }

    private func relayout() {
        guard let screen = NSScreen.main else { return }
        for (index, id) in orderedIDs.enumerated() {
            guard let window = windows[id] else { continue }
            let frame = window.frame
            let offset: CGFloat = CGFloat(index * 40)
            let x = screen.visibleFrame.maxX - frame.width - 20 - offset
            let y = screen.visibleFrame.minY + 20 + offset
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
