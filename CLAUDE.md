# CLAUDE.md

Guidance for future agents working on SleanShot.

## Product Goal

SleanShot is a native macOS app that makes screenshots and screen recordings easier by capturing media, keeping captured items pinned in a screen corner, and letting users annotate, save, copy, or discard them.

## MVP Requirements

- Capture screenshots:
  - Selected area
  - Whole screen
- Record screen:
  - Selected area
  - Whole screen
- After each screenshot or recording:
  - Show the captured item as a pinned corner overlay.
  - Ensure future screenshots/recordings do **not** include SleanShot pinned overlays.
- For every pinned item, support:
  - Open/draw on top
  - Save to file
  - Copy to clipboard
  - Drop/delete
- After drawing on a screenshot, support:
  - Save annotated image to file
  - Copy annotated image to clipboard
  - Drop/delete
- Settings screen MVP:
  - Toggle whether screenshots are automatically copied to clipboard.

## Recommended Native Stack

- Language: Swift
- Main UI: SwiftUI
- Floating overlays/window control: AppKit, especially `NSWindow`
- Screenshot and screen recording: ScreenCaptureKit
- Screenshot annotation: PencilKit first; SwiftUI Canvas only if PencilKit is insufficient
- Settings persistence: `UserDefaults` / `@AppStorage`
- Clipboard: `NSPasteboard`
- Save/export: `NSSavePanel`
- Temporary media storage: app-controlled temp directory

Do not build this as Electron or a web-stack app. SleanShot needs native macOS capture APIs, permissions, floating windows, drag/drop behavior, and low-latency overlays.

## Architecture

Prefer a small modular native app:

```text
SleanShotApp
├── AppCoordinator
├── PermissionManager
├── CaptureEngine
├── RecordingEngine
├── OverlayManager
├── AnnotationEditor
├── ClipboardService
├── FileExportService
└── SettingsStore
```

### AppCoordinator

Owns high-level app flow:

- Starts screenshot or recording flows.
- Receives captured media.
- Creates pinned overlay items.
- Applies settings such as auto-copy screenshots.
- Coordinates save/copy/drop/edit actions.

### PermissionManager

Handles macOS Screen Recording permission state and onboarding.

The app must gracefully handle missing permission. macOS often requires the user to manually enable Screen Recording in System Settings and relaunch the app.

### CaptureEngine

Handles still screenshots through ScreenCaptureKit.

Responsibilities:

- Full-screen screenshot.
- Selected-area screenshot.
- Exclude SleanShot overlay windows from capture.
- Return captured image data to the coordinator.

### RecordingEngine

Handles screen recordings through ScreenCaptureKit.

Responsibilities:

- Full-screen recording.
- Selected-area recording.
- Exclude SleanShot overlay windows from recording.
- Write video to disk immediately.
- Return a file URL plus thumbnail/metadata.

Do not keep raw video buffers in memory after capture. Recordings can become large quickly.

### OverlayManager

Manages pinned capture previews.

Use AppKit `NSWindow` for overlays. SwiftUI-only windows are too limited for precise floating overlay behavior.

Overlay windows should be:

- Borderless
- Floating
- Lightweight
- Draggable if supported
- Excluded from future captures/recordings
- Able to host SwiftUI content if useful

Each overlay should expose actions for open/edit, save, copy, and drop/delete.

### AnnotationEditor

Handles screenshot drawing/markup.

MVP recommendation:

- Use PencilKit for native drawing.
- Load the screenshot as the base image.
- Let the user draw on top.
- Export a flattened annotated image for save/copy.

Recording annotation is out of scope for MVP unless explicitly requested later.

### ClipboardService

Handles copying media to clipboard:

- Raw screenshots
- Annotated screenshots
- Recording file URLs if supported

Respect the `autoCopyScreenshotToClipboard` setting after screenshot capture.

### FileExportService

Handles explicit user saves:

- Screenshots: PNG by default.
- Annotated screenshots: PNG by default.
- Recordings: prefer `.mov` unless the chosen encoding pipeline clearly supports another format.

Use `NSSavePanel` for destination selection.

### SettingsStore

Persist app settings with `UserDefaults` / `@AppStorage`.

Initial setting:

```text
autoCopyScreenshotToClipboard: Bool
```

## Important Implementation Constraints

### Excluding Pinned Items

Pinned previews must not appear in future screenshots or recordings.

Preferred approach:

- Keep pinned previews as identifiable SleanShot windows.
- When configuring ScreenCaptureKit, exclude those windows from the capture/recording content filter.

Do not fake this by rapidly hiding/showing overlays unless ScreenCaptureKit exclusion proves impossible for a specific OS target.

### Multi-Monitor Support

Design capture selection and pinned overlay placement with multiple displays in mind.

Watch for:

- Different display scale factors.
- Retina vs non-Retina coordinates.
- Displays being connected/disconnected.
- Area selection crossing display boundaries.

### Screen Recording Permission

ScreenCaptureKit requires Screen Recording permission for core app functionality. Treat permission UX as part of MVP, not a later enhancement.

### Recording Memory

Recordings must be streamed/written to disk. Pinned recording overlays should show thumbnails or lightweight previews, not retain full video data in memory.

## Suggested Implementation Order

1. [x] Create native macOS app shell.
2. [x] Add Screen Recording permission/onboarding flow.
3. [x] Implement full-screen screenshot.
4. [x] Add pinned overlay window for screenshots.
5. [x] Add copy/save/drop actions for screenshot overlays.
6. [x] Add selected-area screenshot.
7. [x] Implement reliable overlay exclusion from future captures.
8. [x] Add full-screen recording.
9. [x] Add selected-area recording.
10. [x] Add screenshot annotation editor.
11. [x] Add settings screen with auto-copy toggle.

## Non-Goals for MVP

Do not add these unless the user explicitly asks:

- Cloud sync
- Accounts/authentication
- OCR
- Capture history library
- Team sharing
- GIF export
- Advanced image editing suite
- Recording annotation
- Upload/share integrations

## Coding Guidelines

- Prefer native macOS APIs over third-party dependencies.
- Keep components small and testable.
- Do not suppress Swift/type errors.
- Do not introduce large architectural frameworks prematurely.
- Keep capture, overlay, annotation, clipboard, export, and settings responsibilities separate.
- Fix bugs minimally; avoid unrelated refactors.
- Before changing behavior, check `idea.md` and this file for intended scope.

## Verification Expectations

For implementation work, verify at least:

- App builds successfully.
- Screen Recording permission flow handles allowed and denied states.
- Full-screen and area screenshots work.
- Full-screen and area recordings work.
- Pinned overlays do not appear in later captures.
- Save/copy/drop actions work for captured items.
- Annotation save/copy/drop works for screenshots.
- Auto-copy setting changes screenshot clipboard behavior.
- Multi-monitor behavior is tested when practical.
