# Bugs

- **Pinned Overlay Image Size:** The captured screenshot currently renders as a "small square just a bit bigger than the close icon" in the `PinnedOverlayView` instead of filling the allocated 12% proportional window space. Needs investigation into SwiftUI `Image(nsImage:)` scaling or `NSImage` point size decoding.
