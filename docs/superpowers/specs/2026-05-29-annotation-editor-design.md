# Screenshot Annotation Editor

## Goal

Let users draw on top of screenshots using PencilKit, then save, copy, or discard the annotated result.

## Interaction Flow

1. User hovers cursor over a pinned screenshot preview in the overlay.
2. An "Edit" label fades in at the top of the preview.
3. User clicks the preview → annotation editor window opens.
4. Annotation window shows the screenshot at a comfortable size with a PencilKit drawing canvas overlaid.
5. User draws using PencilKit tool picker (pen, highlighter, eraser, etc.).
6. Bottom toolbar has three buttons:
   - **Save** — NSSavePanel to export the flattened annotated PNG.
   - **Copy** — Copy flattened annotated PNG to clipboard.
   - **Discard** — Close without saving.
7. The editor is self-contained — the coordinator fires it and forgets it.

## Architecture

### New: `AnnotationEditing` protocol (SleanShotCore)

```swift
public protocol AnnotationEditing: Sendable {
    @MainActor func editImage(data: Data)
}
```

The protocol is minimal — the editor handles all UI internally. No return value needed since Save/Copy are handled within the editor window.

### New: `AppAnnotationEditor` (SleanShotApp)

`@MainActor` class that conforms to `AnnotationEditing`.

- Creates an NSWindow containing the image + PencilKit canvas.
- Uses a `withUnsafeContinuation` internally to wait for the user to finish (Save/Copy/Discard).
- On Save: flattens drawing + image, shows NSSavePanel, writes PNG.
- On Copy: flattens drawing + image, writes to NSPasteboard.
- On Discard: closes window, no side effects.

### New: `AnnotationCanvasView` (SleanShotApp)

`NSViewRepresentable` wrapping `PKCanvasView`.

- Transparent background so the image behind is visible.
- Loads `PKDrawing` data (or starts empty).
- Exposes a `flatten()` method via coordinator to composite drawing onto the base image.

### Modified: `OverlayActions`

Add a new closure:

```swift
public let edit: @MainActor @Sendable () -> Void
```

### Modified: `AppCoordinator`

- Add an `annotationEditor: AnnotationEditing` dependency.
- In `receiveScreenshot()`, wire the `edit` closure:

```swift
edit: { [annotationEditor, imageData] in
    annotationEditor.editImage(data: imageData)
}
```

### Modified: `PinnedOverlayView`

- Wrap the preview Image in a `Button` or add a `onTapGesture`.
- On hover, show an "Edit" text overlay with fade animation.
- Add `edit` action call to the tap handler.

### Modified: `AppServices`

- Create and inject `AppAnnotationEditor` into the coordinator.

## Annotation Window Layout

- **NSWindow**: titled (`"SleanShot — Annotate"`), resizable, min 400×300, initial size fits image up to 1000×800.
- **Style**: `[.titled, .closable, .resizable, .fullSizeContentView]`.
- **Content**: `NSHostingView` holding a SwiftUI view:
  - `ZStack`:
    - `Image(nsImage:)` scaled to fit.
    - `AnnotationCanvasView` (PencilKit, transparent).
  - Bottom toolbar: `HStack` with Save / Copy / Discard buttons.
- PencilKit `PKToolPicker` appears automatically on canvas activation.

## Flattening

When the user taps Save or Copy:

1. Get the `PKDrawing` from `PKCanvasView`.
2. Create an `NSImage` context at the original image size.
3. Draw the original screenshot first.
4. Draw the PKDrawing on top (via `UIImage` bridge or `NSImage` drawing).
5. Export as PNG `Data`.

This produces the annotated image for disk or clipboard.

## Error Handling

- Flattening failure: show an alert, stay in editor.
- Save panel cancelled: no-op, stay in editor.
- Save write failure: show an alert, stay in editor.
- Copy failure: show an alert, stay in editor.

## Files

| File | Status |
|------|--------|
| `Sources/SleanShotCore/AnnotationEditing.swift` | New |
| `Sources/SleanShotApp/AppAnnotationEditor.swift` | New |
| `Sources/SleanShotApp/AnnotationCanvasView.swift` | New |
| `Sources/SleanShotCore/OverlayActions.swift` | Modify — add `edit` |
| `Sources/SleanShotCore/AppCoordinator.swift` | Modify — add dependency, wire closure |
| `Sources/SleanShotApp/PinnedOverlayView.swift` | Modify — hover "Edit", tap preview |
| `Sources/SleanShotApp/AppServices.swift` | Modify — create editor |
