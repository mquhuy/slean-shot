# Selected-Area Screenshot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add immediate drag-to-capture selected-area screenshots that reuse the existing pinned screenshot flow.

**Architecture:** Core owns selection geometry, selection service protocol, and coordinator routing. The app layer owns AppKit selection windows and ScreenCaptureKit area capture. The selected-area command requests a display-aware selection, captures that rectangle, then calls the same `receiveScreenshot(_:)` path used by full-screen screenshots.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSWindow`, ScreenCaptureKit `SCScreenshotManager`, SwiftPM core test runner, Xcode macOS app target.

---

## File Structure

- Create `Sources/SleanShotCore/CaptureArea.swift`: display-aware selected area and pure geometry helpers.
- Create `Sources/SleanShotCore/AreaSelectionService.swift`: async protocol returning `CaptureArea?`.
- Modify `Sources/SleanShotCore/CaptureEngine.swift`: add `captureArea(_:)`.
- Modify `Sources/SleanShotCore/AppCoordinator.swift`: inject area selection service and handle `.screenshotArea`.
- Modify `Sources/SleanShotCore/SleanShotCommand.swift`: update area screenshot unavailable text because it is no longer a placeholder.
- Modify `Sources/SleanShotCoreTestRunner/main.swift`: add core geometry and coordinator tests.
- Create `Sources/SleanShotApp/AppAreaSelectionService.swift`: app service that presents temporary selection windows and returns a selected area.
- Create `Sources/SleanShotApp/SelectionOverlayWindow.swift`: borderless key-capable overlay window handling Escape.
- Create `Sources/SleanShotApp/SelectionOverlayView.swift`: SwiftUI dimming/drag rectangle UI.
- Modify `Sources/SleanShotApp/AppCaptureEngine.swift`: implement ScreenCaptureKit region capture.
- Modify `Sources/SleanShotApp/AppServices.swift`: construct and inject `AppAreaSelectionService`.
- Modify `SleanShot.xcodeproj/project.pbxproj`: add new app-layer Swift files to the `SleanShot` target.
- Modify `CLAUDE.md`: mark selected-area screenshot done after verification.

---

### Task 1: Core Capture Area Geometry

**Files:**
- Create: `Sources/SleanShotCore/CaptureArea.swift`
- Modify: `Sources/SleanShotCoreTestRunner/main.swift`

- [ ] **Step 1: Write failing tests for normalized rectangles, tiny rejection, and display clamping**

Add these tests after `testOverlayPreviewLayoutUsesScreenProportionPlusPadding()` in `Sources/SleanShotCoreTestRunner/main.swift`:

```swift
func testCaptureAreaNormalizesDragPoints() {
    let display = CaptureDisplay(id: 7, frame: CaptureRect(x: 0, y: 0, width: 800, height: 600), scaleFactor: 2)

    let area = CaptureArea.fromDrag(
        display: display,
        start: CapturePoint(x: 300, y: 220),
        end: CapturePoint(x: 120, y: 80)
    )

    expect(area?.rect == CaptureRect(x: 120, y: 80, width: 180, height: 140), "Drag points should normalize to a positive rectangle")
    expect(area?.display == display, "Area should keep the selected display")
}

func testCaptureAreaRejectsTinySelections() {
    let display = CaptureDisplay(id: 7, frame: CaptureRect(x: 0, y: 0, width: 800, height: 600), scaleFactor: 2)

    let area = CaptureArea.fromDrag(
        display: display,
        start: CapturePoint(x: 100, y: 100),
        end: CapturePoint(x: 104, y: 106)
    )

    expect(area == nil, "Tiny accidental drags should cancel selection")
}

func testCaptureAreaClampsToDisplayBounds() {
    let display = CaptureDisplay(id: 7, frame: CaptureRect(x: 0, y: 0, width: 800, height: 600), scaleFactor: 2)

    let area = CaptureArea.fromDrag(
        display: display,
        start: CapturePoint(x: 760, y: 560),
        end: CapturePoint(x: 900, y: 700)
    )

    expect(area?.rect == CaptureRect(x: 760, y: 560, width: 40, height: 40), "Selection should clamp to the display frame")
}
```

Also add these calls in `runTests()` after `testOverlayPreviewLayoutUsesScreenProportionPlusPadding()`:

```swift
testCaptureAreaNormalizesDragPoints()
testCaptureAreaRejectsTinySelections()
testCaptureAreaClampsToDisplayBounds()
```

- [ ] **Step 2: Run test runner and verify it fails**

Run: `swift run SleanShotCoreTestRunner`

Expected: FAIL because `CaptureDisplay`, `CaptureRect`, `CapturePoint`, and `CaptureArea` are not defined.

- [ ] **Step 3: Add minimal core geometry implementation**

Create `Sources/SleanShotCore/CaptureArea.swift`:

```swift
import Foundation

public struct CapturePoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct CaptureRect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    var maxX: Double { x + width }
    var maxY: Double { y + height }
}

public struct CaptureDisplay: Equatable, Sendable {
    public let id: UInt32
    public let frame: CaptureRect
    public let scaleFactor: Double

    public init(id: UInt32, frame: CaptureRect, scaleFactor: Double) {
        self.id = id
        self.frame = frame
        self.scaleFactor = scaleFactor
    }
}

public struct CaptureArea: Equatable, Sendable {
    public static let minimumSize: Double = 8

    public let display: CaptureDisplay
    public let rect: CaptureRect

    public init(display: CaptureDisplay, rect: CaptureRect) {
        self.display = display
        self.rect = rect
    }

    public static func fromDrag(display: CaptureDisplay, start: CapturePoint, end: CapturePoint) -> CaptureArea? {
        let rawMinX = min(start.x, end.x)
        let rawMinY = min(start.y, end.y)
        let rawMaxX = max(start.x, end.x)
        let rawMaxY = max(start.y, end.y)

        let minX = max(display.frame.x, rawMinX)
        let minY = max(display.frame.y, rawMinY)
        let maxX = min(display.frame.maxX, rawMaxX)
        let maxY = min(display.frame.maxY, rawMaxY)
        let width = max(0, maxX - minX)
        let height = max(0, maxY - minY)

        guard width >= minimumSize, height >= minimumSize else { return nil }

        return CaptureArea(
            display: display,
            rect: CaptureRect(x: minX, y: minY, width: width, height: height)
        )
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `swift run SleanShotCoreTestRunner`

Expected: PASS with `SleanShotCoreTestRunner passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/SleanShotCore/CaptureArea.swift Sources/SleanShotCoreTestRunner/main.swift
git commit -m "feat(core): add capture area geometry"
```

---

### Task 2: Coordinator Area Screenshot Flow

**Files:**
- Create: `Sources/SleanShotCore/AreaSelectionService.swift`
- Modify: `Sources/SleanShotCore/CaptureEngine.swift`
- Modify: `Sources/SleanShotCore/AppCoordinator.swift`
- Modify: `Sources/SleanShotCore/SleanShotCommand.swift`
- Modify: `Sources/SleanShotCoreTestRunner/main.swift`

- [ ] **Step 1: Write failing tests for cancel and successful area capture**

Replace `MockCaptureEngine` in `Sources/SleanShotCoreTestRunner/main.swift` with:

```swift
struct MockCaptureEngine: CaptureEngine {
    var areaData = Data("mock_area_image".utf8)
    final class State: @unchecked Sendable {
        let lock = NSLock()
        var capturedAreas: [CaptureArea] = []
    }

    let state = State()

    func captureFullScreen() async throws -> Data {
        return Data("mock_image".utf8)
    }

    func captureArea(_ area: CaptureArea) async throws -> Data {
        state.lock.lock()
        state.capturedAreas.append(area)
        state.lock.unlock()
        return areaData
    }

    var capturedAreas: [CaptureArea] {
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.capturedAreas
    }
}

struct MockAreaSelectionService: AreaSelectionService {
    let selection: CaptureArea?

    func selectArea() async -> CaptureArea? {
        selection
    }
}
```

Add tests after `testCoordinatorFullScreenCapture()`:

```swift
@MainActor
func testCoordinatorAreaScreenshotCancelDoesNotCaptureOrPin() async {
    let clipboard = MockClipboardService()
    let overlays = MockOverlayManager()
    let permissions = MockPermissionManager()
    let capture = MockCaptureEngine()
    let coordinator = AppCoordinator(
        settings: SettingsStore(autoCopyScreenshotToClipboard: true),
        clipboard: clipboard,
        overlays: overlays,
        fileExport: MockFileExportService(),
        permissionManager: permissions,
        captureEngine: capture,
        areaSelection: MockAreaSelectionService(selection: nil)
    )

    try? await coordinator.handle(.screenshotArea)

    expect(capture.capturedAreas.isEmpty, "Cancelled area selection should not capture")
    expect(overlays.pinnedItems.isEmpty, "Cancelled area selection should not pin overlays")
    expect(clipboard.copiedData == nil, "Cancelled area selection should not copy image data")
}

@MainActor
func testCoordinatorAreaScreenshotCapturesSelectionAndPinsScreenshot() async {
    let clipboard = MockClipboardService()
    let overlays = MockOverlayManager()
    let permissions = MockPermissionManager()
    let capture = MockCaptureEngine()
    let display = CaptureDisplay(id: 7, frame: CaptureRect(x: 0, y: 0, width: 800, height: 600), scaleFactor: 2)
    let area = CaptureArea(display: display, rect: CaptureRect(x: 20, y: 30, width: 120, height: 90))
    let coordinator = AppCoordinator(
        settings: SettingsStore(autoCopyScreenshotToClipboard: true),
        clipboard: clipboard,
        overlays: overlays,
        fileExport: MockFileExportService(),
        permissionManager: permissions,
        captureEngine: capture,
        areaSelection: MockAreaSelectionService(selection: area)
    )

    try? await coordinator.handle(.screenshotArea)

    expect(capture.capturedAreas == [area], "Area screenshot should capture selected area")
    expect(overlays.pinnedItems.count == 1, "Area screenshot should pin one screenshot")
    expect(overlays.pinnedItems.first?.imageData == Data("mock_area_image".utf8), "Pinned screenshot should use captured area data")
    expect(clipboard.copiedData == Data("mock_area_image".utf8), "Area screenshot should reuse auto-copy flow")
}
```

Add calls in `runTests()` after `await testCoordinatorFullScreenCapture()`:

```swift
await testCoordinatorAreaScreenshotCancelDoesNotCaptureOrPin()
await testCoordinatorAreaScreenshotCapturesSelectionAndPinsScreenshot()
```

- [ ] **Step 2: Run test runner and verify it fails**

Run: `swift run SleanShotCoreTestRunner`

Expected: FAIL because `AreaSelectionService`, `captureArea(_:)`, and the new `AppCoordinator` initializer parameter are not implemented.

- [ ] **Step 3: Add area selection protocol**

Create `Sources/SleanShotCore/AreaSelectionService.swift`:

```swift
public protocol AreaSelectionService: Sendable {
    func selectArea() async -> CaptureArea?
}

public struct NoAreaSelectionService: AreaSelectionService {
    public init() {}

    public func selectArea() async -> CaptureArea? {
        nil
    }
}
```

- [ ] **Step 4: Extend capture engine protocol**

Modify `Sources/SleanShotCore/CaptureEngine.swift`:

```swift
import Foundation

public protocol CaptureEngine: Sendable {
    func captureFullScreen() async throws -> Data
    func captureArea(_ area: CaptureArea) async throws -> Data
}

public enum CaptureError: Error, Equatable {
    case permissionDenied
    case permissionNeedsRestart
    case captureFailed(String)
}
```

- [ ] **Step 5: Wire coordinator selection flow**

Modify `Sources/SleanShotCore/AppCoordinator.swift` so it stores and uses `areaSelection`:

```swift
public actor AppCoordinator {
    private let settings: SettingsStore
    private let clipboard: ClipboardService
    private let overlays: OverlayManaging
    private let fileExport: FileExportService
    private let permissionManager: PermissionManaging
    private let captureEngine: CaptureEngine
    private let areaSelection: AreaSelectionService

    public init(
        settings: SettingsStore,
        clipboard: ClipboardService,
        overlays: OverlayManaging,
        fileExport: FileExportService,
        permissionManager: PermissionManaging,
        captureEngine: CaptureEngine,
        areaSelection: AreaSelectionService = NoAreaSelectionService()
    ) {
        self.settings = settings
        self.clipboard = clipboard
        self.overlays = overlays
        self.fileExport = fileExport
        self.permissionManager = permissionManager
        self.captureEngine = captureEngine
        self.areaSelection = areaSelection
    }

    public func handle(_ command: SleanShotCommand) async throws {
        switch command {
        case .screenshotFullScreen:
            guard permissionManager.hasScreenCaptureAccess else {
                _ = await permissionManager.requestScreenCaptureAccess()
                throw CaptureError.permissionDenied
            }

            let data = try await captureEngine.captureFullScreen()
            await receiveScreenshot(data)

        case .screenshotArea:
            guard permissionManager.hasScreenCaptureAccess else {
                _ = await permissionManager.requestScreenCaptureAccess()
                throw CaptureError.permissionDenied
            }

            guard let area = await areaSelection.selectArea() else { return }
            let data = try await captureEngine.captureArea(area)
            await receiveScreenshot(data)

        case .recordArea, .recordFullScreen:
            throw CaptureError.captureFailed(command.unavailableMessage)
        }
    }
```

Keep the existing `receiveScreenshot(_:)` and `receiveRecording(fileURL:thumbnailData:)` implementations unchanged below this code.

- [ ] **Step 6: Update area screenshot unavailable text test and implementation**

In `testCaptureCommandsAreUnavailableUntilEnginesExist()`, update expected messages:

```swift
expect(
    unavailableMessages == [
        "Area screenshots are available.",
        "Full-screen screenshots are not implemented yet.",
        "Area recording is not implemented yet.",
        "Full-screen recording is not implemented yet."
    ],
    "Menu commands should be honest placeholders until capture engines exist"
)
```

In `Sources/SleanShotCore/SleanShotCommand.swift`, update `.screenshotArea`:

```swift
case .screenshotArea:
    "Area screenshots are available."
```

- [ ] **Step 7: Run tests and verify they pass**

Run: `swift run SleanShotCoreTestRunner`

Expected: PASS with `SleanShotCoreTestRunner passed`.

- [ ] **Step 8: Commit**

```bash
git add Sources/SleanShotCore/AreaSelectionService.swift Sources/SleanShotCore/CaptureEngine.swift Sources/SleanShotCore/AppCoordinator.swift Sources/SleanShotCore/SleanShotCommand.swift Sources/SleanShotCoreTestRunner/main.swift
git commit -m "feat(core): route area screenshots"
```

---

### Task 3: AppKit Area Selection Overlay

**Files:**
- Create: `Sources/SleanShotApp/AppAreaSelectionService.swift`
- Create: `Sources/SleanShotApp/SelectionOverlayWindow.swift`
- Create: `Sources/SleanShotApp/SelectionOverlayView.swift`
- Modify: `Sources/SleanShotApp/AppServices.swift`
- Modify: `SleanShot.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create key-capable selection window**

Create `Sources/SleanShotApp/SelectionOverlayWindow.swift`:

```swift
import AppKit

final class SelectionOverlayWindow: NSWindow {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
}
```

- [ ] **Step 2: Create SwiftUI selection view**

Create `Sources/SleanShotApp/SelectionOverlayView.swift`:

```swift
import SwiftUI
import SleanShotCore

struct SelectionOverlayView: View {
    let display: CaptureDisplay
    let onFinish: (CaptureArea?) -> Void

    @State private var start: CGPoint?
    @State private var current: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()

                if let rect = selectionRect {
                    Rectangle()
                        .fill(Color.clear)
                        .background(.clear)
                        .border(Color.white, width: 1)
                        .overlay(Rectangle().stroke(Color.blue, lineWidth: 2))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }

                VStack {
                    Text("Drag to capture. Press Esc to cancel.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.top, 28)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if start == nil {
                            start = value.startLocation
                        }
                        current = value.location
                    }
                    .onEnded { value in
                        let area = areaFromDrag(start: value.startLocation, end: value.location, viewHeight: proxy.size.height)
                        onFinish(area)
                    }
            )
        }
    }

    private var selectionRect: CGRect? {
        guard let start, let current else { return nil }
        let minX = min(start.x, current.x)
        let minY = min(start.y, current.y)
        return CGRect(x: minX, y: minY, width: abs(current.x - start.x), height: abs(current.y - start.y))
    }

    private func areaFromDrag(start: CGPoint, end: CGPoint, viewHeight: CGFloat) -> CaptureArea? {
        let appKitStart = CapturePoint(x: display.frame.x + start.x, y: display.frame.y + (viewHeight - start.y))
        let appKitEnd = CapturePoint(x: display.frame.x + end.x, y: display.frame.y + (viewHeight - end.y))
        return CaptureArea.fromDrag(display: display, start: appKitStart, end: appKitEnd)
    }
}
```

- [ ] **Step 3: Create area selection service**

Create `Sources/SleanShotApp/AppAreaSelectionService.swift`:

```swift
import AppKit
import SwiftUI
import SleanShotCore

@MainActor
final class AppAreaSelectionService: AreaSelectionService {
    private var activeWindows: [SelectionOverlayWindow] = []
    private var continuation: CheckedContinuation<CaptureArea?, Never>?
    private var didFinish = false

    func selectArea() async -> CaptureArea? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.didFinish = false
            self.presentSelectionWindow()
        }
    }

    private func presentSelectionWindow() {
        let screens = NSScreen.screens
        let targetScreen = NSScreen.main ?? screens.first
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
        continuation?.resume(returning: area)
    }
}
```

- [ ] **Step 4: Inject the app selection service**

Modify the service construction in `Sources/SleanShotApp/AppServices.swift`:

```swift
let permissions = AppPermissionManager()
let capture = AppCaptureEngine()
let areaSelection = AppAreaSelectionService()

self.coordinator = AppCoordinator(
    settings: settings,
    clipboard: clipboard,
    overlays: overlays,
    fileExport: fileExport,
    permissionManager: permissions,
    captureEngine: capture,
    areaSelection: areaSelection
)
```

- [ ] **Step 5: Add new app files to Xcode target**

Open `SleanShot.xcodeproj/project.pbxproj` and add file references/build files for:

```text
Sources/SleanShotApp/AppAreaSelectionService.swift
Sources/SleanShotApp/SelectionOverlayWindow.swift
Sources/SleanShotApp/SelectionOverlayView.swift
```

Use the same groups and `PBXSourcesBuildPhase` pattern as `AppOverlayManager.swift` and `PinnedOverlayView.swift`. Do not modify unrelated project settings.

- [ ] **Step 6: Build and fix only compile errors from this task**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project SleanShot.xcodeproj -scheme SleanShot -configuration Debug -destination 'platform=macOS' build`

Expected: This may fail because `AppCaptureEngine` has not implemented `captureArea(_:)` yet. If the only failure is missing `captureArea(_:)`, proceed to Task 4. If selection overlay files fail to compile, fix those compile errors before proceeding.

- [ ] **Step 7: Commit**

Commit only if the selection overlay files compile aside from the known `captureArea(_:)` protocol conformance error. If so:

```bash
git add Sources/SleanShotApp/AppAreaSelectionService.swift Sources/SleanShotApp/SelectionOverlayWindow.swift Sources/SleanShotApp/SelectionOverlayView.swift Sources/SleanShotApp/AppServices.swift SleanShot.xcodeproj/project.pbxproj
git commit -m "feat(app): add area selection overlay"
```

If the app cannot compile because of the missing protocol method, combine this commit with Task 4 instead.

---

### Task 4: ScreenCaptureKit Area Capture

**Files:**
- Modify: `Sources/SleanShotApp/AppCaptureEngine.swift`

- [ ] **Step 1: Implement `captureArea(_:)`**

Modify `Sources/SleanShotApp/AppCaptureEngine.swift`:

```swift
public func captureArea(_ area: CaptureArea) async throws -> Data {
    let content: SCShareableContent
    do {
        if #available(macOS 14.4, *) {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } else {
            content = try await SCShareableContent.current
        }
    } catch {
        throw CaptureError.captureFailed("Could not get shareable content")
    }

    guard let display = content.displays.first(where: { $0.displayID == area.display.id }) ?? content.displays.first else {
        throw CaptureError.captureFailed("No displays found")
    }

    let scale = area.display.scaleFactor
    let sourceRect = CGRect(
        x: area.rect.x * scale,
        y: area.rect.y * scale,
        width: area.rect.width * scale,
        height: area.rect.height * scale
    )

    let config = SCStreamConfiguration()
    config.width = Int(area.rect.width * scale)
    config.height = Int(area.rect.height * scale)
    config.sourceRect = sourceRect
    config.showsCursor = false

    let filter = SCContentFilter(display: display, excludingWindows: [])

    do {
        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        let bitmapImage = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw CaptureError.captureFailed("Could not generate PNG data")
        }
        return pngData
    } catch {
        throw CaptureError.captureFailed(error.localizedDescription)
    }
}
```

- [ ] **Step 2: Verify package and app builds**

Run:

```bash
swift build
swift run SleanShotCoreTestRunner
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project SleanShot.xcodeproj -scheme SleanShot -configuration Debug -destination 'platform=macOS' build
```

Expected: all commands pass. If `sourceRect` coordinates are visibly wrong in manual testing, fix the coordinate conversion in the smallest possible change and rerun all three commands.

- [ ] **Step 3: Commit**

```bash
git add Sources/SleanShotApp/AppCaptureEngine.swift
git commit -m "feat(app): capture selected screen area"
```

If Task 3 could not be committed due to protocol conformance, include Task 3 files in this commit and use:

```bash
git add Sources/SleanShotApp/AppAreaSelectionService.swift Sources/SleanShotApp/SelectionOverlayWindow.swift Sources/SleanShotApp/SelectionOverlayView.swift Sources/SleanShotApp/AppServices.swift Sources/SleanShotApp/AppCaptureEngine.swift SleanShot.xcodeproj/project.pbxproj
git commit -m "feat(app): add selected area capture"
```

---

### Task 5: Roadmap Update and Manual Verification

**Files:**
- Modify: `CLAUDE.md`
- Optional modify: `HISTORY.md`

- [ ] **Step 1: Update roadmap checkbox**

In `CLAUDE.md`, change selected-area screenshot from unchecked to checked:

```markdown
6. [x] Add selected-area screenshot.
```

- [ ] **Step 2: Add a short history note**

Append to `HISTORY.md`:

```markdown

## 2026-05-29: Selected-Area Screenshot

- Added immediate drag-to-capture selected-area screenshots.
- Reused the existing screenshot receive/pin/copy/save/drop flow.
- Added core geometry tests for normalized, tiny, and clamped selections.
```

- [ ] **Step 3: Run required automated verification**

Run:

```bash
swift build
swift run SleanShotCoreTestRunner
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project SleanShot.xcodeproj -scheme SleanShot -configuration Debug -destination 'platform=macOS' build
```

Expected: all commands pass.

- [ ] **Step 4: Manual verification**

Launch the built app and verify:

```text
1. Screenshot Area opens a dim selection overlay.
2. Drag and release captures immediately.
3. The pinned overlay shows only the selected area.
4. Copy, Save, and Drop still work on the pinned selected-area screenshot.
5. Escape cancels without creating a pinned overlay.
6. Tiny accidental drag cancels without creating a pinned overlay.
7. Multi-monitor behavior is checked when practical.
```

- [ ] **Step 5: Commit docs**

```bash
git add CLAUDE.md HISTORY.md
git commit -m "docs: update area screenshot progress"
```

---

## Self-Review Notes

- Spec coverage: immediate capture, Escape cancel, tiny drag cancel, display-aware geometry, coordinator reuse of screenshot flow, ScreenCaptureKit area capture, and manual verification are all covered.
- Scope: this plan intentionally excludes post-drag resize handles, confirmation buttons, and reliable pinned-overlay exclusion. Overlay exclusion remains roadmap step 7.
- Type consistency: `CapturePoint`, `CaptureRect`, `CaptureDisplay`, `CaptureArea`, `AreaSelectionService`, and `captureArea(_:)` are defined before later tasks use them.
