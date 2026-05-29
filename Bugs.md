# Bugs

- [x] **Pinned Overlay Image Size:** Fixed by passing an explicit proportional preview size into `PinnedOverlayView` instead of relying on `.frame(maxWidth: .infinity, maxHeight: .infinity)` inside an AppKit-hosted root view.
