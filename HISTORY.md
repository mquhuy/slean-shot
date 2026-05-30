# Project History

## 2026-05-28: Capture Pipeline and Overlays

**Completed Steps 2-4 of the MVP Roadmap:**
- Merged the initial menu bar app shell into `main`.
- Implemented Screen Recording permissions using CoreGraphics (`CGPreflightScreenCaptureAccess`).
- Built the `CaptureEngine` using Apple's `ScreenCaptureKit` to seamlessly capture full-screen screenshots.
- Designed a floating, borderless `NSWindow` overlay manager in AppKit hosting a SwiftUI `PinnedOverlayView` to display the captured thumbnail in the corner of the screen.
- Wired all dependencies securely into `AppCoordinator`, adhering to strict Swift 6 concurrency (`actor` and `Sendable` updates).

**Key Learnings & Debugging:**
- Addressed a major macOS quirk where Xcode's Ad-Hoc code signatures change on every rebuild. This causes the kernel to silently revoke Screen Recording permissions (resulting in a 100% transparent image capture) even though the toggle in System Settings remains "On". The fix requires removing the app via the minus (`-`) button in System Settings and re-prompting.

**Outstanding Issues:**
- Tracked a bug in `Bugs.md`: the `PinnedOverlayView` renders the thumbnail as a small square instead of taking up the intended 12% proportional window space.

**Next Up:**
- Step 5: Add copy/save/drop actions for the screenshot overlays.

## 2026-05-29: Selected-Area Screenshot

- Added immediate drag-to-capture selected-area screenshots.
- Reused the existing screenshot receive/pin/copy/save/drop flow.
- Added core geometry tests for normalized, tiny, and clamped selections.

## 2026-05-30: Recording, Overlay Exclusion, Settings Wiring (Steps 7–11)

Completed the remaining MVP roadmap items on `feature/overlay-actions`.

- **Fixed a broken build on `main`:** the test runner constructed `AppCoordinator`
  without the (newly required) `annotationEditor`. Gave the dependency a
  `NoAnnotationEditor` default so production and tests construct it the same way.
- **Step 7 — Overlay exclusion:** captures and recordings now exclude every
  SleanShot-owned window via `SCShareableContent.sleanShotWindows()` (matched by
  bundle id / process id), so pinned overlays, the selection overlay, the editor,
  and the recording control panel never appear in captured media.
- **Steps 8 & 9 — Recording:** added `RecordingEngine`/`RecordingHandle` to the
  core and `AppRecordingEngine` (ScreenCaptureKit `SCStream` → `AVAssetWriter`,
  H.264 `.mov` streamed to a temp dir, never holding raw buffers; thumbnail via
  `AVAssetImageGenerator` on stop). Full-screen and selected-area both supported.
  A floating `RecordingControlPanel` plus a menu item provide Stop; the coordinator
  ignores a second start while already recording.
- **Recording overlays:** copy puts the file URL on the pasteboard, save copies the
  `.mov` via `NSSavePanel`, drop removes the overlay and deletes the temp file.
  `PinnedOverlayView` shows the thumbnail with a play badge and no Edit affordance.
- **Step 11 — Settings wiring:** the coordinator now reads the auto-copy toggle
  *live* through a `SettingsProviding` abstraction backed by `UserDefaultsSettingsStore`,
  instead of a throwaway snapshot that ignored the user's choice.

**Verification:** `SleanShotCore` builds and the full `SleanShotCoreTestRunner`
suite passes (incl. new recording-flow tests). The app target (`SleanShotApp`)
could not be compiled in this environment — only Command Line Tools are installed,
not Xcode — so the ScreenCaptureKit/AVFoundation app code must be built and run in
Xcode to confirm.
