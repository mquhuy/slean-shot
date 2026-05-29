# Overlay Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add always-visible Copy, Save, and Drop actions to pinned screenshot overlays.

**Architecture:** Extend core with `OverlayActions` and `FileExportService`, update `OverlayManaging` to accept actions and support removal, and wire actions through `AppCoordinator`. Implement app-layer export and overlay UI controls with always-visible icon buttons.

**Tech Stack:** Swift, SwiftUI, AppKit, NSSavePanel, NSPasteboard.

---

## File Structure

- Create core protocols:
  - `Sources/SleanShotCore/FileExportService.swift`
  - `Sources/SleanShotCore/OverlayActions.swift`
- Modify core coordinator & overlay protocol:
  - `Sources/SleanShotCore/AppCoordinator.swift`
- Update core test runner:
  - `Sources/SleanShotCoreTestRunner/main.swift`
- App layer export + wiring:
  - Create `Sources/SleanShotApp/AppFileExportService.swift`
  - Modify `Sources/SleanShotApp/AppServices.swift`
- Overlay UI:
  - Modify `Sources/SleanShotApp/AppOverlayManager.swift`
  - Modify `Sources/SleanShotApp/PinnedOverlayView.swift`

---

### Task 1: Core Actions + Coordinator Wiring

**Files:**
- Create: `Sources/SleanShotCore/FileExportService.swift`
- Create: `Sources/SleanShotCore/OverlayActions.swift`
- Modify: `Sources/SleanShotCore/AppCoordinator.swift`
- Modify: `Sources/SleanShotCoreTestRunner/main.swift`

- [ ] **Step 1: Write failing test for overlay actions**

Add a new test function to `Sources/SleanShotCoreTestRunner/main.swift` that expects `copy`, `save`, and `drop` to call the right services.

```swift
@MainActor
func testOverlayActionsCopySaveDrop() async {
    let clipboard = MockClipboardService()
    let exporter = MockFileExportService()
    let overlays = MockOverlayManager()
    let permissions = MockPermissionManager()
    let capture = MockCaptureEngine()

    let coordinator = AppCoordinator(
        settings: SettingsStore(autoCopyScreenshotToClipboard: false),
        clipboard: clipboard,
        overlays: overlays,
        fileExport: exporter,
        permissionManager: permissions,
        captureEngine: capture
    )

    let imageData = Data([0xDE, 0xAD, 0xBE, 0xEF])
    let item = await coordinator.receiveScreenshot(imageData)

    guard let actions = overlays.actionsByID[item.id] else {
        fatalError("Overlay actions should be created")
    }

    actions.copy()
    actions.save()
    actions.drop()

    expect(clipboard.copiedData == imageData, "Copy should write image data to clipboard")
    expect(exporter.savedData == imageData, "Save should pass image data to export service")
    expect(overlays.removedIDs == [item.id], "Drop should remove the overlay")
}
```

Register the test in `runTests()`:

```swift
    await testOverlayActionsCopySaveDrop()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift run SleanShotCoreTestRunner`
Expected: FAIL with missing symbols (`FileExportService`, `OverlayActions`, new `OverlayManaging` signature).

- [ ] **Step 3: Add core protocols + actions**

Create `Sources/SleanShotCore/FileExportService.swift`:

```swift
import Foundation

public protocol FileExportService: Sendable {
    @MainActor func saveImageData(_ data: Data)
}
```

Create `Sources/SleanShotCore/OverlayActions.swift`:

```swift
import Foundation

public struct OverlayActions: Sendable {
    public let copy: @MainActor @Sendable () -> Void
    public let save: @MainActor @Sendable () -> Void
    public let drop: @MainActor @Sendable () -> Void

    public init(
        copy: @escaping @MainActor @Sendable () -> Void,
        save: @escaping @MainActor @Sendable () -> Void,
        drop: @escaping @MainActor @Sendable () -> Void
    ) {
        self.copy = copy
        self.save = save
        self.drop = drop
    }
}
```

- [ ] **Step 4: Update core overlay protocol + coordinator**

In `Sources/SleanShotCore/AppCoordinator.swift`, update `OverlayManaging` and inject `FileExportService`:

```swift
public protocol OverlayManaging: Sendable {
    @MainActor func pin(_ item: CaptureItem, actions: OverlayActions)
    @MainActor func remove(_ id: UUID)
}
```

Update `AppCoordinator` initializer signature and store `fileExport`:

```swift
private let fileExport: FileExportService

public init(
    settings: SettingsStore,
    clipboard: ClipboardService,
    overlays: OverlayManaging,
    fileExport: FileExportService,
    permissionManager: PermissionManaging,
    captureEngine: CaptureEngine
) {
    self.settings = settings
    self.clipboard = clipboard
    self.overlays = overlays
    self.fileExport = fileExport
    self.permissionManager = permissionManager
    self.captureEngine = captureEngine
}
```

Update `receiveScreenshot` to create actions and pin with them:

```swift
@discardableResult
public func receiveScreenshot(_ imageData: Data) async -> CaptureItem {
    let item = CaptureItem.screenshot(imageData: imageData)
    let actions = OverlayActions(
        copy: { [clipboard] in
            clipboard.copyImageData(imageData)
        },
        save: { [fileExport] in
            fileExport.saveImageData(imageData)
        },
        drop: { [overlays, id = item.id] in
            overlays.remove(id)
        }
    )

    await overlays.pin(item, actions: actions)

    if settings.autoCopyScreenshotToClipboard {
        clipboard.copyImageData(imageData)
    }

    return item
}
```

Update `receiveRecording` to pass no-op actions (drop should still work):

```swift
let actions = OverlayActions(
    copy: {},
    save: {},
    drop: { [overlays, id = item.id] in
        overlays.remove(id)
    }
)
await overlays.pin(item, actions: actions)
```

- [ ] **Step 5: Update mocks in test runner**

Add a mock file exporter and update overlay mock to store actions.

```swift
final class MockFileExportService: FileExportService {
    private var _savedData: Data?
    private let lock = NSLock()

    var savedData: Data? {
        lock.lock()
        defer { lock.unlock() }
        return _savedData
    }

    @MainActor
    func saveImageData(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        _savedData = data
    }
}

@MainActor
final class MockOverlayManager: OverlayManaging {
    var pinnedItems: [CaptureItem] = []
    var actionsByID: [UUID: OverlayActions] = [:]
    var removedIDs: [UUID] = []

    func pin(_ item: CaptureItem, actions: OverlayActions) {
        pinnedItems.append(item)
        actionsByID[item.id] = actions
    }

    func remove(_ id: UUID) {
        removedIDs.append(id)
    }
}
```

Update existing test initializers to pass `fileExport: MockFileExportService()`.

- [ ] **Step 6: Run tests to verify pass**

Run: `swift run SleanShotCoreTestRunner`
Expected: `SleanShotCoreTestRunner passed`

- [ ] **Step 7: Commit**

```bash
git add Sources/SleanShotCore Sources/SleanShotCoreTestRunner
git commit -m "feat(core): add overlay actions and file export protocol"
```

---

### Task 2: App Export Service + Clipboard Error Handling

**Files:**
- Create: `Sources/SleanShotApp/AppFileExportService.swift`
- Modify: `Sources/SleanShotApp/AppServices.swift`

- [ ] **Step 1: Implement AppFileExportService**

Create `Sources/SleanShotApp/AppFileExportService.swift`:

```swift
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
```

- [ ] **Step 2: Update AppClipboardService to report errors**

In `Sources/SleanShotApp/AppServices.swift`, update `AppClipboardService` to hold `alertPresenter` and report failure from `setData`:

```swift
final class AppClipboardService: Sendable, ClipboardService {
    private let alertPresenter: AlertPresenting

    init(alertPresenter: AlertPresenting) {
        self.alertPresenter = alertPresenter
    }

    func copyImageData(_ data: Data) {
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            let success = pasteboard.setData(data, forType: .png)
            if !success {
                self.alertPresenter.show(message: "Copy failed. Please try again.")
            }
        }
    }
}
```

- [ ] **Step 3: Inject FileExportService in AppServices**

Update the coordinator initialization in `Sources/SleanShotApp/AppServices.swift`:

```swift
let clipboard = AppClipboardService(alertPresenter: alertPresenter)
let exporter = AppFileExportService(alertPresenter: alertPresenter)
let overlays = AppOverlayManager()

self.coordinator = AppCoordinator(
    settings: settings,
    clipboard: clipboard,
    overlays: overlays,
    fileExport: exporter,
    permissionManager: permissions,
    captureEngine: capture
)
```

- [ ] **Step 4: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/SleanShotApp/AppFileExportService.swift Sources/SleanShotApp/AppServices.swift
git commit -m "feat(app): add file export service for screenshot saves"
```

---

### Task 3: Overlay UI Actions

**Files:**
- Modify: `Sources/SleanShotApp/AppOverlayManager.swift`
- Modify: `Sources/SleanShotApp/PinnedOverlayView.swift`

- [ ] **Step 1: Update overlay manager to accept actions + removal**

In `Sources/SleanShotApp/AppOverlayManager.swift`:

```swift
public func pin(_ item: CaptureItem, actions: OverlayActions) {
    let hostingController = NSHostingController(
        rootView: PinnedOverlayView(item: item, actions: actions)
    )
    // ... existing window setup ...
}

public func remove(_ id: UUID) {
    windows[id]?.close()
    windows.removeValue(forKey: id)
}
```

- [ ] **Step 2: Add always-visible action row in PinnedOverlayView**

Update `Sources/SleanShotApp/PinnedOverlayView.swift`:

```swift
struct PinnedOverlayView: View {
    let item: CaptureItem
    let actions: OverlayActions

    // ... nsImage ...

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // existing image content...

            HStack(spacing: 8) {
                Button(action: actions.copy) {
                    Image(systemName: "doc.on.doc")
                }
                Button(action: actions.save) {
                    Image(systemName: "square.and.arrow.down")
                }
                Button(action: actions.drop) {
                    Image(systemName: "trash")
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6), in: Capsule())
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(8)

            Button(action: actions.drop) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(8)
            .offset(x: 4, y: -4)
        }
        .padding(20)
    }
}
```

- [ ] **Step 3: Verify build**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project SleanShot.xcodeproj -scheme SleanShot -configuration Debug -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Sources/SleanShotApp/AppOverlayManager.swift Sources/SleanShotApp/PinnedOverlayView.swift
git commit -m "feat(app): add always-visible overlay actions"
```

---

## Plan Self-Review

- **Spec coverage:** UI action row + architecture, protocol changes, and error handling are covered by Tasks 1–3.
- **Placeholder scan:** No TODOs or vague steps present.
- **Type consistency:** `OverlayActions`, `FileExportService`, and `OverlayManaging` signatures match across tasks.
