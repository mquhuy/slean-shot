# Selected-Area Screenshot Design

## Goal

Add selected-area screenshot capture using an immediate drag-to-capture overlay. The user chooses **Screenshot Area** from the menu, drags a rectangle, releases the mouse, and SleanShot captures that area into the existing pinned overlay flow.

## User Experience

- Choosing **Screenshot Area** starts a modal selection mode.
- SleanShot shows a dimmed overlay across the active screen area, with a highlighted rectangle while dragging.
- Mouse down starts selection, dragging resizes the rectangle, and mouse up captures immediately.
- Escape cancels selection and returns to normal without creating an overlay.
- A zero-size or tiny accidental drag cancels instead of capturing.

Post-drag resize handles and confirmation buttons are out of scope for this slice.

## Architecture

Add a small app-layer selection component and keep AppKit details out of core coordination.

```text
AppCoordinator
├── AreaSelectionService protocol
├── CaptureEngine.captureArea(...)
└── existing receiveScreenshot flow

SleanShotApp
├── AppAreaSelectionService
├── SelectionOverlayWindow
└── SelectionOverlayView
```

`AreaSelectionService` returns a selected capture rectangle or `nil` if cancelled. `AppCoordinator` uses it only for `.screenshotArea`, then calls the capture engine and routes the image data through `receiveScreenshot(_:)` so auto-copy, pinned overlays, and overlay actions remain unchanged.

## Coordinate Model

The selection service should return a display-aware area that can be passed to ScreenCaptureKit without guessing between SwiftUI, AppKit, and pixel coordinate systems. The first implementation should support selecting within one display. If multi-display selection would cross display boundaries, capture should use the display where the drag started and clamp the rectangle to that display.

Use app/core value types for the selected area so coordinate math can be unit-tested without AppKit windows.

## Capture Behavior

Extend `CaptureEngine` with selected-area capture. The ScreenCaptureKit implementation should capture only the selected rectangle from the selected display. The selection overlay must close before capture starts so it does not appear in the resulting screenshot.

Reliable exclusion of existing pinned overlays remains roadmap step 7 and is not part of this slice, but this design should not make it harder. The selected-area path should reuse the same capture engine boundary that later adds overlay window exclusion.

## Error Handling

- Missing Screen Recording permission follows the existing permission flow.
- Escape or tiny selection returns quietly without showing an error.
- Capture failures should log to the console for now and avoid creating a broken pinned item.

## Testing

Core tests should cover:

- Drag start/end normalization into a positive rectangle.
- Tiny selections are rejected.
- Selection clamping stays within the chosen display.
- `.screenshotArea` does not capture when the selection service returns `nil`.
- `.screenshotArea` routes captured image data through the same pin/copy flow as full-screen screenshots.

Manual verification should cover:

- Drag selection captures the selected visible area.
- Escape cancels without a pinned overlay.
- Tiny accidental drags cancel.
- Existing overlay actions still work on the resulting pinned screenshot.
- Multi-monitor behavior is checked when practical.
