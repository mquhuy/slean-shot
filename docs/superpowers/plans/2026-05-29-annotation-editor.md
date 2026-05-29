# Annotation Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users draw on pinned screenshots via PencilKit and save/copy/discard the annotated result.

**Architecture:** New `AnnotationEditing` protocol, `AppAnnotationEditor` (NSWindow + continuation), `AnnotationCanvasView` (PKCanvasView wrapper). `OverlayActions` gets an `edit` closure. Coordinator fires it and forgets it.

**Tech Stack:** PencilKit (PKCanvasView), AppKit (NSWindow), SwiftUI (NSHostingView), NSPasteboard, NSSavePanel

---

### Task 1: Create `AnnotationEditing` protocol

**Files:**
- Create: `Sources/SleanShotCore/AnnotationEditing.swift`

- [ ] **Create the file**

```swift
import Foundation

public protocol AnnotationEditing: Sendable {
    @MainActor func editImage(data: Data)
}
```

- [ ] **Commit**

```bash
git add Sources/SleanShotCore/AnnotationEditing.swift
git commit -m "feat: add AnnotationEditing protocol"
```

---

### Task 2: Create `AnnotationCanvasView` (PencilKit wrapper)

**Files:**
- Create: `Sources/SleanShotApp/AnnotationCanvasView.swift`

- [ ] **Create the file**

```swift
import PencilKit
import SwiftUI

struct AnnotationCanvasView: NSViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeNSView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.allowsFingerDrawing = false
        return canvas
    }

    func updateNSView(_ nsView: PKCanvasView, context: Context) {
        nsView.drawing = drawing
    }
}
```

- [ ] **Commit**

```bash
git add Sources/SleanShotApp/AnnotationCanvasView.swift
git commit -m "feat: add PKCanvasView wrapper"
```

---

### Task 3: Create `AppAnnotationEditor`

**Files:**
- Create: `Sources/SleanShotApp/AppAnnotationEditor.swift`

- [ ] **Create the file**

```swift
import AppKit
import OSLog
import PencilKit
import SwiftUI
import SleanShotCore

private let annotationLogger = Logger(subsystem: "com.huy.SleanShot", category: "AnnotationEditor")

@MainActor
final class AppAnnotationEditor: AnnotationEditing {
    private let alertPresenter: AlertPresenting
    private let clipboardService: ClipboardService

    init(alertPresenter: AlertPresenting, clipboardService: ClipboardService) {
        self.alertPresenter = alertPresenter
        self.clipboardService = clipboardService
    }

    func editImage(data: Data) {
        annotationLogger.info("editImage called size=\(data.count)")
        Task {
            await presentEditor(data: data)
        }
    }

    private func presentEditor(data: Data) async {
        guard let image = NSImage(data: data) else {
            alertPresenter.show(message: "Could not load image for annotation.")
            return
        }

        let maxW: CGFloat = 1000
        let maxH: CGFloat = 800
        let imageSize = image.size
        let scale = min(maxW / imageSize.width, maxH / imageSize.height, 1.0)
        let editorSize = NSSize(
            width: min(imageSize.width * scale, maxW),
            height: min(imageSize.height * scale, maxH) + 50
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: editorSize.width, height: editorSize.height),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "SleanShot — Annotate"
        window.minSize = NSSize(width: 400, height: 300)
        window.center()

        enum EditorAction {
            case saved
            case copied
            case discarded
        }

        let action = await withUnsafeContinuation { continuation in
            let hostingView = NSHostingView(
                rootView: AnnotationEditorView(
                    image: image,
                    flattenedSize: imageSize,
                    onSave: { [weak window] annotatedData in
                        guard let window = window else { return }
                        let panel = NSSavePanel()
                        panel.allowedContentTypes = [.png]
                        panel.canCreateDirectories = true
                        panel.nameFieldStringValue = "Screenshot.png"
                        let response = panel.runModal()
                        guard response == .OK, let url = panel.url else {
                            return
                        }
                        do {
                            try annotatedData.write(to: url)
                            continuation.resume(returning: .saved)
                            window.orderOut(nil)
                        } catch {
                            let alert = NSAlert()
                            alert.messageText = "Save failed. Please try again."
                            alert.runModal()
                        }
                    },
                    onCopy: { [weak self, weak window] annotatedData in
                        self?.clipboardService.copyImageData(annotatedData)
                        continuation.resume(returning: .copied)
                        window?.orderOut(nil)
                    },
                    onDiscard: { [weak window] in
                        continuation.resume(returning: .discarded)
                        window?.orderOut(nil)
                    }
                )
            )
            hostingView.frame = NSRect(origin: .zero, size: editorSize)
            hostingView.autoresizingMask = [.width, .height]
            window.contentView = hostingView
            window.makeKeyAndOrderFront(nil)
        }

        annotationLogger.info("editor closed action=\(String(describing: action))")
    }
}

private struct AnnotationEditorView: View {
    let image: NSImage
    let flattenedSize: NSSize
    let onSave: (Data) -> Void
    let onCopy: (Data) -> Void
    let onDiscard: () -> Void

    @State private var drawing = PKDrawing()

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black.opacity(0.05)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                AnnotationCanvasView(drawing: $drawing)
            }

            HStack(spacing: 16) {
                Button("Save") {
                    if let data = flatten() {
                        onSave(data)
                    }
                }
                Button("Copy") {
                    if let data = flatten() {
                        onCopy(data)
                    }
                }
                Button("Discard", role: .destructive) {
                    onDiscard()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
    }

    private func flatten() -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let w = cgImage.width
        let h = cgImage.height
        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w,
            pixelsHigh: h,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        bitmapRep.size = image.size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        image.draw(at: .zero, from: .zero, operation: .copy, fraction: 1.0)
        let uiImage = drawing.image(from: CGRect(x: 0, y: 0, width: w, height: h), scale: 1.0)
        if let cgDrawing = uiImage.cgImage {
            let drawingImage = NSImage(cgImage: cgDrawing, size: image.size)
            drawingImage.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
        NSGraphicsContext.restoreGraphicsState()

        return bitmapRep.representation(using: .png, properties: [:])
    }
}
```

- [ ] **Commit**

```bash
git add Sources/SleanShotApp/AppAnnotationEditor.swift
git commit -m "feat: add annotation editor window"
```

---

### Task 4: Add `edit` action to `OverlayActions`

**Files:**
- Modify: `Sources/SleanShotCore/OverlayActions.swift`

- [ ] **Add the `edit` closure**

```swift
import Foundation

public struct OverlayActions: Sendable {
    public let copy: @MainActor @Sendable () -> Void
    public let save: @MainActor @Sendable () -> Void
    public let drop: @MainActor @Sendable () -> Void
    public let edit: @MainActor @Sendable () -> Void

    public init(
        copy: @escaping @MainActor @Sendable () -> Void,
        save: @escaping @MainActor @Sendable () -> Void,
        drop: @escaping @MainActor @Sendable () -> Void,
        edit: @escaping @MainActor @Sendable () -> Void
    ) {
        self.copy = copy
        self.save = save
        self.drop = drop
        self.edit = edit
    }
}
```

- [ ] **Commit**

```bash
git add Sources/SleanShotCore/OverlayActions.swift
git commit -m "feat: add edit action to OverlayActions"
```

---

### Task 5: Wire annotation editor in `AppCoordinator`

**Files:**
- Modify: `Sources/SleanShotCore/AppCoordinator.swift`

- [ ] **Add `annotationEditor` dependency and wire edit closure in `receiveScreenshot()`**

```swift
import Foundation
import OSLog

private let coordinatorLogger = Logger(subsystem: "com.huy.SleanShot", category: "AppCoordinator")

public protocol ClipboardService: Sendable {
    func copyImageData(_ data: Data)
}

public protocol OverlayManaging: Sendable {
    @MainActor func pin(_ item: CaptureItem, actions: OverlayActions)
    @MainActor func remove(_ id: UUID)
}

public actor AppCoordinator {
    private let settings: SettingsStore
    private let clipboard: ClipboardService
    private let overlays: OverlayManaging
    private let fileExport: FileExportService
    private let permissionManager: PermissionManaging
    private let captureEngine: CaptureEngine
    private let areaSelection: AreaSelectionService
    private let annotationEditor: AnnotationEditing

    public init(
        settings: SettingsStore,
        clipboard: ClipboardService,
        overlays: OverlayManaging,
        fileExport: FileExportService,
        permissionManager: PermissionManaging,
        captureEngine: CaptureEngine,
        areaSelection: AreaSelectionService = NoAreaSelectionService(),
        annotationEditor: AnnotationEditing
    ) {
        self.settings = settings
        self.clipboard = clipboard
        self.overlays = overlays
        self.fileExport = fileExport
        self.permissionManager = permissionManager
        self.captureEngine = captureEngine
        self.areaSelection = areaSelection
        self.annotationEditor = annotationEditor
    }

    // ... handle, receiveScreenshot, receiveRecording stay the same ...

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
            },
            edit: { [annotationEditor, imageData] in
                annotationEditor.editImage(data: imageData)
            }
        )

        await overlays.pin(item, actions: actions)

        if settings.autoCopyScreenshotToClipboard {
            clipboard.copyImageData(imageData)
        }

        return item
    }
}
```

Only the `init`, `annotationEditor` property, and `receiveScreenshot` edit closure changed. The rest of the file stays as-is.

- [ ] **Commit**

```bash
git add Sources/SleanShotCore/AppCoordinator.swift
git commit -m "feat: wire annotation editor in coordinator"
```

---

### Task 6: Add hover "Edit" + tap to pinned overlay preview

**Files:**
- Modify: `Sources/SleanShotApp/PinnedOverlayView.swift`

- [ ] **Wrap preview in tappable view with hover state**

```swift
import SwiftUI
import SleanShotCore

struct PinnedOverlayView: View {
    let item: CaptureItem
    let actions: OverlayActions
    let previewSize: CGSize

    @State private var isHovering = false

    var nsImage: NSImage? {
        guard let data = item.imageData else { return nil }
        return NSImage(data: data)
    }

    var body: some View {
        ZStack {
            if let img = nsImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: previewSize.width, height: previewSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                    .onTapGesture {
                        actions.edit()
                    }
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isHovering = hovering
                        }
                    }
                    .overlay(alignment: .top) {
                        if isHovering {
                            Text("Edit")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Capsule())
                                .padding(.top, 8)
                                .transition(.opacity)
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.8))
                    .frame(width: previewSize.width, height: previewSize.height)
            }

            HStack(spacing: 8) {
                actionButton(systemName: "doc.on.doc", accessibilityLabel: "Copy", action: actions.copy)
                actionButton(systemName: "square.and.arrow.down", accessibilityLabel: "Save", action: actions.save)
                actionButton(systemName: "trash", accessibilityLabel: "Drop", action: actions.drop)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
            .offset(x: -4, y: -4)
        }
        .padding(20)
    }

    private func actionButton(systemName: String, accessibilityLabel: String, action: @escaping @MainActor @Sendable () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
```

- [ ] **Commit**

```bash
git add Sources/SleanShotApp/PinnedOverlayView.swift
git commit -m "feat: add hover Edit + tap to open annotation"
```

---

### Task 7: Wire `AppAnnotationEditor` in `AppServices`

**Files:**
- Modify: `Sources/SleanShotApp/AppServices.swift`

- [ ] **Create and inject AppAnnotationEditor**

Change the coordinator init in `AppServices`:

```swift
            let settings = SettingsStore()
            let clipboard = AppClipboardService(alertPresenter: alertPresenter)
            let overlays = AppOverlayManager()
            let fileExport = AppFileExportService(alertPresenter: alertPresenter)
            let permissions = AppPermissionManager()
            let capture = AppCaptureEngine()
            let areaSelection = AppAreaSelectionService()
            let annotation = AppAnnotationEditor(
                alertPresenter: alertPresenter,
                clipboardService: clipboard
            )

            self.coordinator = AppCoordinator(
                settings: settings,
                clipboard: clipboard,
                overlays: overlays,
                fileExport: fileExport,
                permissionManager: permissions,
                captureEngine: capture,
                areaSelection: areaSelection,
                annotationEditor: annotation
            )
```

- [ ] **Commit**

```bash
git add Sources/SleanShotApp/AppServices.swift
git commit -m "feat: wire AppAnnotationEditor in AppServices"
```

---

### Task 8: Build and verify

- [ ] **Build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project SleanShot.xcodeproj -scheme SleanShot -configuration Debug -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Run and test** — launch the app, take a screenshot, hover over the pinned preview to see "Edit", click to open the annotation editor, draw on it, try Save/Copy/Discard.
