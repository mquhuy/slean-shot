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
