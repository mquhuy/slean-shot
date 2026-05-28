# Overlay Actions Design

**Goal:** Add always-visible Copy, Save, and Drop actions to screenshot overlays so users can immediately act on a captured image.

**Scope:** Screenshot overlays only. Recording overlays, annotation editor, and area capture remain out of scope.

## User Experience

- Every pinned screenshot overlay shows three action buttons (Copy, Save, Drop) at all times.
- Buttons are placed in a compact, always-visible row at the top-left of the overlay.
- The existing close (“x”) remains top-right.
- Copy and Save operate on the captured screenshot image data.
- Drop removes the overlay from screen.

## UI Layout

- Top-left action row uses SF Symbols:
  - Copy: `doc.on.doc`
  - Save: `square.and.arrow.down`
  - Drop: `trash`
- Buttons sit on a dark capsule background for contrast on any image.
- Buttons are always visible and enabled for screenshots.

## Architecture & Data Flow

- Add `FileExportService` protocol in `SleanShotCore` for saving image data (implemented in app layer using `NSSavePanel`).
- Add `OverlayActions` struct in `SleanShotCore` containing `copy`, `save`, and `drop` closures.
- Update `OverlayManaging` to `pin(_ item: CaptureItem, actions: OverlayActions)` so the overlay can call back into actions.
- Add `remove(_ id: UUID)` to `OverlayManaging` to close overlays from core.
- `AppCoordinator` builds the `OverlayActions` for each screenshot:
  - `copy` calls `ClipboardService.copyImageData`.
  - `save` calls `FileExportService.saveImageData`.
  - `drop` calls `OverlayManaging.remove(id)`.

## Error Handling

- Copy: if pasteboard fails, show an alert via `AlertPresenting`.
- Save: if `NSSavePanel` is canceled, do nothing; if save fails, show an error alert.
- Drop: always succeeds (close overlay window).

## Testing Strategy

- Extend core test runner to verify that actions are wired and invoked correctly via `AppCoordinator`.
- Use mock `ClipboardService`, `FileExportService`, and `OverlayManaging` to assert that actions dispatch as expected.

## Non-Goals

- No recording overlay actions.
- No annotation editor integration.
- No hover-only UI or advanced styling.
