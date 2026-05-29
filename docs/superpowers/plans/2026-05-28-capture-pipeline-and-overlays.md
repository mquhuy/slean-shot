# Capture Pipeline and Overlays Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the permission flow, full-screen screenshot capture using ScreenCaptureKit, and display the result in a pinned AppKit overlay window.

**Architecture:** We add `PermissionManaging` and `CaptureEngine` protocols to `SleanShotCore`. `AppCoordinator` handles commands, checks permission, triggers capture, and forwards the image to `OverlayManaging`. In `SleanShotApp`, we implement these using `CGPreflightScreenCaptureAccess`, `ScreenCaptureKit` (`SCScreenshotManager`), and a floating `NSWindow` hosting SwiftUI.

**Tech Stack:** Swift, ScreenCaptureKit, CoreGraphics, AppKit, SwiftUI.

## User Stories

1. **Permission Handling:** As a user, when I try to take a screenshot and haven't granted Screen Recording permission, SleanShot should prompt me to grant it via System Settings.
2. **Full-Screen Capture:** As a user, I want to capture my entire screen using the "Screenshot Full Screen" menu command.
3. **Pinned Overlay:** As a user, when I take a screenshot, it should appear as a borderless floating overlay in the corner of my screen.

---

### Task 1: Add Protocols and Update Coordinator

**Files:**
- Create: `Sources/SleanShotCore/PermissionManaging.swift`
- Create: `Sources/SleanShotCore/CaptureEngine.swift`
- Modify: `Sources/SleanShotCore/AppCoordinator.swift`
- Modify: `Sources/SleanShotCoreTestRunner/main.swift`

- [ ] **Step 1: Write `PermissionManaging.swift` and `CaptureEngine.swift`**

```swift
// Sources/SleanShotCore/PermissionManaging.swift
import Foundation

public protocol PermissionManaging: Sendable {
    var hasScreenCaptureAccess: Bool { get }
    func requestScreenCaptureAccess() async -> Bool
}

// Sources/SleanShotCore/CaptureEngine.swift
import Foundation

public protocol CaptureEngine: Sendable {
    func captureFullScreen() async throws -> Data
}

public enum CaptureError: Error, Equatable {
    case permissionDenied
    case captureFailed(String)
}
```

- [ ] **Step 2: Update `AppCoordinator.swift` to handle commands**

Update `AppCoordinator` to take `PermissionManaging` and `CaptureEngine` in its initializer. Add an `async` `handle(_ command: SleanShotCommand)` method.

```swift
// Replace the top of Sources/SleanShotCore/AppCoordinator.swift
import Foundation

public protocol ClipboardService: Sendable {
    func copyImageData(_ data: Data)
}

public protocol OverlayManaging: Sendable {
    @MainActor func pin(_ item: CaptureItem)
}

public actor AppCoordinator {
    private let settings: SettingsStore
    private let clipboard: ClipboardService
    private let overlays: OverlayManaging
    private let permissionManager: PermissionManaging
    private let captureEngine: CaptureEngine

    public init(
        settings: SettingsStore,
        clipboard: ClipboardService,
        overlays: OverlayManaging,
        permissionManager: PermissionManaging,
        captureEngine: CaptureEngine
    ) {
        self.settings = settings
        self.clipboard = clipboard
        self.overlays = overlays
        self.permissionManager = permissionManager
        self.captureEngine = captureEngine
    }

    public func handle(_ command: SleanShotCommand) async throws {
        switch command {
        case .screenshotFullScreen:
            guard permissionManager.hasScreenCaptureAccess else {
                let granted = await permissionManager.requestScreenCaptureAccess()
                if !granted { throw CaptureError.permissionDenied }
                return // User needs to grant and likely restart app, or we abort for now.
            }
            
            let data = try await captureEngine.captureFullScreen()
            await receiveScreenshot(data)
            
        case .screenshotArea, .recordArea, .recordFullScreen:
            throw CaptureError.captureFailed(command.unavailableMessage)
        }
    }

    @discardableResult
    public func receiveScreenshot(_ imageData: Data) async -> CaptureItem {
        let item = CaptureItem.screenshot(imageData: imageData)
        await overlays.pin(item)

        if settings.autoCopyScreenshotToClipboard {
            clipboard.copyImageData(imageData)
        }

        return item
    }
    
    @discardableResult
    public func receiveRecording(fileURL: URL, thumbnailData: Data?) async -> CaptureItem {
        let item = CaptureItem.recording(fileURL: fileURL, thumbnailData: thumbnailData)
        await overlays.pin(item)
        return item
    }
}
```

- [ ] **Step 3: Update Test Runner for `AppCoordinator`**

In `Sources/SleanShotCoreTestRunner/main.swift`, add stub implementations for the new protocols and test the full screen screenshot flow.

```swift
// Add above `func runTests()` in Sources/SleanShotCoreTestRunner/main.swift

struct MockPermissionManager: PermissionManaging {
    var hasScreenCaptureAccess: Bool = true
    func requestScreenCaptureAccess() async -> Bool { return true }
}

struct MockCaptureEngine: CaptureEngine {
    func captureFullScreen() async throws -> Data {
        return Data("mock_image".utf8)
    }
}

actor MockOverlayManager: OverlayManaging {
    var pinnedItems: [CaptureItem] = []
    func pin(_ item: CaptureItem) {
        pinnedItems.append(item)
    }
}

actor MockClipboardService: ClipboardService {
    var copiedData: Data?
    func copyImageData(_ data: Data) {
        copiedData = data
    }
}

func testCoordinatorFullScreenCapture() async {
    let settings = SettingsStore(defaults: .standard)
    let clipboard = MockClipboardService()
    let overlays = MockOverlayManager()
    let permissions = MockPermissionManager()
    let capture = MockCaptureEngine()
    
    let coordinator = AppCoordinator(
        settings: settings,
        clipboard: clipboard,
        overlays: overlays,
        permissionManager: permissions,
        captureEngine: capture
    )
    
    try? await coordinator.handle(.screenshotFullScreen)
    
    let pinned = await overlays.pinnedItems
    assert(pinned.count == 1, "Should have pinned one item")
    assert(pinned.first?.kind == .screenshot, "Item should be a screenshot")
    assert(pinned.first?.imageData == Data("mock_image".utf8), "Item should have correct data")
    print("testCoordinatorFullScreenCapture passed")
}

// Inside runTests()
await testCoordinatorFullScreenCapture()
```

Fix existing `AppCoordinator` instantiations in the app shell (we'll do this in Task 2 & 4). For now, comment out or stub in `AppServices.swift` if it breaks `swift build` (or do it all in one commit). Actually, let's fix `AppServices.swift` enough to build.

```swift
// Modify Sources/SleanShotApp/AppServices.swift AppServices initializer:
// Temporarily use fatalError or dummy implementations if needed, but since we are changing it soon, just provide dummy ones.

// Add at bottom of AppServices.swift for now:
struct DummyPermissionManager: PermissionManaging {
    var hasScreenCaptureAccess: Bool { true }
    func requestScreenCaptureAccess() async -> Bool { true }
}
struct DummyCaptureEngine: CaptureEngine {
    func captureFullScreen() async throws -> Data { Data() }
}
```

Wait, `AppServices` currently doesn't instantiate `AppCoordinator`! It just has `perform(_ command:)`. So no `AppCoordinator` instances to fix in `AppServices.swift` yet.

- [ ] **Step 4: Verify build and tests pass**

Run: `swift build && swift run SleanShotCoreTestRunner`
Expected: Passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/SleanShotCore Sources/SleanShotCoreTestRunner
git commit -m "feat(core): add permission and capture engine protocols to coordinator"
```

### Task 2: Implement PermissionManager

**Files:**
- Create: `Sources/SleanShotApp/AppPermissionManager.swift`

- [ ] **Step 1: Write `AppPermissionManager`**

```swift
// Sources/SleanShotApp/AppPermissionManager.swift
import CoreGraphics
import Foundation
import SleanShotCore

public struct AppPermissionManager: PermissionManaging {
    public init() {}
    
    public var hasScreenCaptureAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }
    
    public func requestScreenCaptureAccess() async -> Bool {
        // CGRequestScreenCaptureAccess is synchronous and blocks until user responds
        // or returns immediately if already granted/denied.
        return CGRequestScreenCaptureAccess()
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Passes.

- [ ] **Step 3: Commit**

```bash
git add Sources/SleanShotApp/AppPermissionManager.swift
git commit -m "feat(app): implement AppPermissionManager using CoreGraphics"
```

### Task 3: Implement CaptureEngine

**Files:**
- Create: `Sources/SleanShotApp/AppCaptureEngine.swift`

- [ ] **Step 1: Write `AppCaptureEngine`**

```swift
// Sources/SleanShotApp/AppCaptureEngine.swift
import AppKit
import Foundation
import ScreenCaptureKit
import SleanShotCore

public struct AppCaptureEngine: CaptureEngine {
    public init() {}
    
    public func captureFullScreen() async throws -> Data {
        guard let content = try? await SCShareableContent.current else {
            throw CaptureError.captureFailed("Could not get shareable content")
        }
        
        guard let display = content.displays.first else {
            throw CaptureError.captureFailed("No displays found")
        }
        
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.showsCursor = false
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        do {
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            
            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                throw CaptureError.captureFailed("Could not generate PNG data")
            }
            
            return pngData
        } catch {
            throw CaptureError.captureFailed(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Passes.

- [ ] **Step 3: Commit**

```bash
git add Sources/SleanShotApp/AppCaptureEngine.swift
git commit -m "feat(app): implement AppCaptureEngine using ScreenCaptureKit"
```

### Task 4: Wire AppServices to AppCoordinator

**Files:**
- Modify: `Sources/SleanShotApp/AppServices.swift`
- Modify: `Sources/SleanShotApp/SleanShotApp.swift`

- [ ] **Step 1: Update `AppServices` to use `AppCoordinator`**

```swift
// Replace the top of Sources/SleanShotApp/AppServices.swift up to `quit()`
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
    private let coordinator: AppCoordinator

    init(
        alertPresenter: AlertPresenting = NSAlertPresenter(),
        coordinator: AppCoordinator? = nil
    ) {
        self.alertPresenter = alertPresenter
        if let coordinator = coordinator {
            self.coordinator = coordinator
        } else {
            let settings = SettingsStore(defaults: .standard)
            let clipboard = AppClipboardService()
            let overlays = AppOverlayManager() // We will create this in the next task
            let permissions = AppPermissionManager()
            let capture = AppCaptureEngine()
            
            self.coordinator = AppCoordinator(
                settings: settings,
                clipboard: clipboard,
                overlays: overlays,
                permissionManager: permissions,
                captureEngine: capture
            )
        }
    }

    func perform(_ command: SleanShotCommand) {
        Task {
            do {
                try await coordinator.handle(command)
            } catch CaptureError.permissionDenied {
                alertPresenter.show(message: "Screen Recording permission is required. Please grant it in System Settings and try again.")
            } catch CaptureError.captureFailed(let reason) {
                alertPresenter.show(message: reason)
            } catch {
                alertPresenter.show(message: "An unknown error occurred.")
            }
        }
    }

    func quit() {
// ... rest of AppServices.swift ...
```

- [ ] **Step 2: Create a minimal `AppOverlayManager` stub so it builds**

```swift
// Add to bottom of Sources/SleanShotApp/AppServices.swift
final class AppOverlayManager: OverlayManaging {
    @MainActor
    func pin(_ item: CaptureItem) {
        // Will implement in next task
    }
}
```

Wait, `AppClipboardService` is `@MainActor ClipboardService`, but in `AppCoordinator` `ClipboardService` is marked `Sendable`. Let's ensure `AppClipboardService` works.
In `Sources/SleanShotApp/AppServices.swift`:
```swift
final class AppClipboardService: ClipboardService {
    func copyImageData(_ data: Data) {
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(data, forType: .png)
        }
    }
}
```
Replace the existing `AppClipboardService` with this non-actor version that dispatches to main, avoiding protocol actor isolation mismatches.

- [ ] **Step 3: Verify build**

Run: `swift build`
Expected: Passes.

- [ ] **Step 4: Commit**

```bash
git add Sources/SleanShotApp/AppServices.swift
git commit -m "feat(app): wire AppServices to AppCoordinator"
```

### Task 5: Implement AppKit OverlayManager

**Files:**
- Create: `Sources/SleanShotApp/AppOverlayManager.swift`
- Create: `Sources/SleanShotApp/PinnedOverlayView.swift`
- Modify: `Sources/SleanShotApp/AppServices.swift`

- [ ] **Step 1: Write `PinnedOverlayView` in SwiftUI**

```swift
// Sources/SleanShotApp/PinnedOverlayView.swift
import SwiftUI
import SleanShotCore

struct PinnedOverlayView: View {
    let item: CaptureItem
    let closeAction: () -> Void
    
    var nsImage: NSImage? {
        guard let data = item.imageData else { return nil }
        return NSImage(data: data)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let img = nsImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 10)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 300, height: 200)
            }
            
            Button(action: closeAction) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .padding(4)
        }
        .padding(16) // Room for shadow
    }
}
```

- [ ] **Step 2: Write `AppOverlayManager`**

```swift
// Sources/SleanShotApp/AppOverlayManager.swift
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
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
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
            let x = screenFrame.maxX - 350
            let y = screenFrame.minY + 50
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.makeKeyAndOrderFront(nil)
        windows[item.id] = window
    }
    
    private func close(_ id: UUID) {
        windows[id]?.close()
        windows.removeValue(forKey: id)
    }
}
```

- [ ] **Step 3: Remove the stub from `AppServices.swift`**

Remove the `AppOverlayManager` stub from `Sources/SleanShotApp/AppServices.swift` now that the real one exists.

- [ ] **Step 4: Verify build**

Run: `swift build`
Expected: Passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/SleanShotApp/PinnedOverlayView.swift Sources/SleanShotApp/AppOverlayManager.swift Sources/SleanShotApp/AppServices.swift
git commit -m "feat(app): implement pinned overlay windows using AppKit and SwiftUI"
```
