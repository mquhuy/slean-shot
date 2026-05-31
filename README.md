# SleanShot

A native macOS app that makes screenshots and screen recordings easier by capturing media, keeping captured items pinned in a screen corner, and letting users annotate, save, copy, or discard them instantly.

## Overview

SleanShot streamlines your screenshot and screen recording workflow. After capturing, your media appears as a floating overlay in the screen corner—ready to annotate, save, copy to clipboard, or delete. All without cluttering your desktop or requiring additional window management.

**Key Innovation**: SleanShot's pinned overlays are automatically excluded from future captures and recordings, so they never accidentally appear in your next screenshot or video.

## Features

- **Full-Screen & Area Screenshots**: Capture entire displays or select specific regions
- **Full-Screen & Area Screen Recordings**: Record video with the same flexibility
- **Smart Pinned Overlays**: Captured media appears as floating previews in the corner
- **Automatic Overlay Exclusion**: Pinned overlays never appear in subsequent captures
- **Screenshot Annotation**: Draw and markup screenshots using native PencilKit
- **One-Click Actions**: Copy to clipboard, save to file, edit, or delete
- **Auto-Copy Setting**: Optionally copy screenshots to clipboard immediately
- **Customizable Global Shortcuts**: Assign your own system-wide hotkeys (none set by default), or reuse the macOS screenshot combos (⌘⇧3 / ⌘⇧4 / ⌘⇧5)
- **Multi-Monitor Support**: Works seamlessly across multiple displays
- **Menu Bar Integration**: Control the app from the macOS menu bar

## System Requirements

- **macOS 14.0** or later (Sonoma or newer)
- **Screen Recording Permission**: Required for screenshot and recording functionality
- **Xcode 15.0+**: For building from source

## Installation

### Building from Source

SleanShot is built with Swift 6 and SwiftUI. The project uses Swift Package Manager for core dependencies.

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/SleanShot.git
   cd SleanShot
   ```

2. **Open in Xcode**:
   ```bash
   open -a Xcode .
   ```

3. **Select the SleanShot target** and build with Cmd+B

4. **Run the app** with Cmd+R

5. **Grant Screen Recording Permission**:
   - macOS will prompt for Screen Recording access on first launch
   - If denied, enable it in System Settings > Privacy & Security > Screen Recording
   - The app may need to be re-added after changing permissions

### First Launch

On first launch, macOS will request Screen Recording permission. This is required for the app to function. You'll see a prompt to allow SleanShot access to screen content.

A **welcome tip** also appears, explaining that SleanShot starts with no keyboard shortcuts and how to set them. Untick "Open this at startup" to stop it showing on future launches; reopen it anytime from Settings.

## Usage Guide

> **Keyboard shortcuts are off by default.** Trigger any capture from the menu bar, or assign your own global shortcuts in Settings (see [Keyboard Shortcuts](#keyboard-shortcuts)). Shortcuts shown below are only active if you've assigned them.

### Taking Screenshots

**Full-Screen Screenshot**:
- Select **Screenshot Full Screen** from the menu bar (or your assigned shortcut)
- The screenshot appears as a pinned overlay

**Area Screenshot**:
- Select **Screenshot Area** from the menu bar (or your assigned shortcut)
- Click and drag to select the region
- The screenshot appears as a pinned overlay

### Recording Your Screen

**Full-Screen Recording**:
- Select **Record Full Screen** from the menu bar (or your assigned shortcut)
- Recording indicator appears in the corner
- Click "Stop Recording" in the menu (or use your shortcut) to finish
- The recording appears as a pinned overlay with a play badge

**Area Recording**:
- Select **Record Area** from the menu bar (or your assigned shortcut)
- Click and drag to select the recording region
- A red border shows the recording frame
- Click "Stop Recording" (or use your shortcut) to finish

### Keyboard Shortcuts

SleanShot ships with **no global shortcuts assigned**, so it never clashes with your existing setup out of the box. Configure them in Settings → Global Shortcuts:

- **Set your own**: Click a command's field and press the key combination. Shortcuts work system-wide. Use the ✕ to clear one.
- **Use the macOS combos**: The "Use macOS shortcuts (⌘⇧3 / ⌘⇧4 / ⌘⇧5)" button assigns the familiar system screenshot keys to SleanShot.

macOS reserves ⌘⇧3 / ⌘⇧4 / ⌘⇧5 for its own screenshots and gives them priority over apps. To use those combos in SleanShot you must **first disable them in macOS**, then assign them here (order matters — otherwise the system intercepts the keypress). The "Show me how" button walks through exactly which entries to uncheck:

| Combo | macOS entry to uncheck | SleanShot use |
|-------|------------------------|---------------|
| ⌘⇧3 | "Save picture of screen as a file" | Screenshot Full Screen |
| ⌘⇧4 | "Save picture of selected area as a file" | Screenshot Area |
| ⌘⇧5 | "Screenshot and recording options" | Record Area |

Changes take effect immediately — no restart needed.

### Working with Pinned Items

Each pinned overlay (screenshot or recording) provides four quick actions:

- **Copy**: Copy the image to clipboard (screenshots) or file URL to clipboard (recordings)
- **Save**: Open a save dialog to export the file to your preferred location
- **Edit** (Screenshots only): Open the annotation editor to draw on the screenshot
- **Drop**: Delete the pinned item immediately

### Annotating Screenshots

1. Click the **Edit** button on a pinned screenshot overlay
2. Use the annotation tools to draw, highlight, or mark up the image
3. Choose:
   - **Save**: Export the annotated image as PNG
   - **Copy**: Copy the annotated image to clipboard
   - **Drop**: Discard without saving

### Settings

Access Settings from the menu bar or press `Cmd+,`:

- **Auto-Copy Screenshots**: When enabled, screenshots are automatically copied to clipboard after capture
- **Recording Border**: Toggle the red frame drawn around the recording area
- **Global Shortcuts**: Assign, clear, or apply the macOS screenshot combos for each capture command (see [Keyboard Shortcuts](#keyboard-shortcuts))
- **Welcome Tip**: Toggle the startup tip, or reopen it on demand

## Architecture

SleanShot follows a modular architecture with clean separation of concerns:

```
SleanShotApp
├── AppCoordinator          # High-level app flow orchestration
├── PermissionManager       # macOS Screen Recording permission handling
├── CaptureEngine           # Still screenshot capture via ScreenCaptureKit
├── RecordingEngine         # Screen recording via ScreenCaptureKit
├── OverlayManager          # Pinned overlay window management (AppKit/NSWindow)
├── AnnotationEditor        # Screenshot markup using PencilKit
├── ClipboardService        # Copy to clipboard via NSPasteboard
├── FileExportService       # Save via NSSavePanel
└── SettingsStore           # Persistent settings via UserDefaults
```

### Core Components

**AppCoordinator** (`Sources/SleanShotCore/AppCoordinator.swift`)
- Central actor managing app workflows
- Handles screenshot and recording commands
- Applies settings and coordinates save/copy/drop actions
- Ensures permission checks before capture

**CaptureEngine** (`Sources/SleanShotCore/CaptureEngine.swift`)
- Uses Apple's `ScreenCaptureKit` framework
- Captures full-screen and area-selected screenshots
- Automatically excludes SleanShot overlay windows from capture

**RecordingEngine** (`Sources/SleanShotCore/RecordingEngine.swift`)
- Streams video to disk using `AVAssetWriter`
- Supports full-screen and area-selected recordings
- Encodes to H.264 `.mov` format
- Generates thumbnails without keeping raw video in memory

**OverlayManager** (`Sources/SleanShotApp/AppOverlayManager.swift`)
- Manages floating `NSWindow` instances for previews
- Integrates SwiftUI `PinnedOverlayView` for thumbnail rendering
- Handles overlay positioning and multi-monitor support
- Automatically excludes overlay windows from ScreenCaptureKit captures

**AnnotationEditor** (`Sources/SleanShotCore/AnnotationEditing.swift`)
- Provides screenshot markup capabilities
- Uses PencilKit for native drawing experience
- Exports flattened annotated images for save/copy

**SettingsStore** (`Sources/SleanShotCore/SettingsStore.swift`)
- Persists user preferences with `UserDefaults`
- Provides live settings updates to the coordinator
- Supports `autoCopyScreenshotToClipboard` toggle

### Concurrency Model

SleanShot uses Swift 6 strict concurrency:

- `AppCoordinator` is an `actor` for thread-safe coordination
- Services conform to `Sendable` protocol
- Main thread operations marked with `@MainActor`
- No data races or unsafe concurrency patterns

### Multi-Monitor Support

The app handles multiple displays gracefully:

- Capture area selection works across display boundaries
- Overlay placement adapts to current display and scale factors
- Respects Retina vs non-Retina coordinate systems
- Detects display connection/disconnection

## Development Setup

### Prerequisites

- Xcode 15.0 or later
- Swift 6.0 or later
- macOS 14.0 or later (for building)

### Project Structure

```
SleanShot/
├── Package.swift                    # Swift Package Manager manifest
├── Sources/
│   ├── SleanShotCore/              # Core business logic (framework)
│   │   ├── AppCoordinator.swift     # App orchestration
│   │   ├── CaptureEngine.swift      # Screenshot capture
│   │   ├── RecordingEngine.swift    # Screen recording
│   │   ├── AnnotationEditing.swift  # Markup handling
│   │   ├── OverlayActions.swift     # Overlay action definitions
│   │   ├── SettingsStore.swift      # Settings persistence
│   │   ├── CaptureItem.swift        # Captured media model
│   │   ├── CaptureArea.swift        # Geometry for area selection
│   │   ├── FileExportService.swift  # Save dialog handling
│   │   ├── PermissionManaging.swift # Permission protocols
│   │   └── ... (supporting types)
│   │
│   ├── SleanShotApp/                # macOS app UI (executable)
│   │   ├── SleanShotApp.swift       # Menu bar app entry point
│   │   ├── AppCoordinator+Services  # Dependency injection
│   │   ├── AppServices.swift        # Service containers
│   │   ├── AppCaptureEngine.swift   # ScreenCaptureKit integration
│   │   ├── AppRecordingEngine.swift # AVFoundation recording
│   │   ├── AppOverlayManager.swift  # NSWindow management
│   │   ├── PinnedOverlayView.swift  # SwiftUI overlay UI
│   │   ├── SettingsView.swift       # Settings screen
│   │   ├── AnnotationCanvasView.swift # Drawing UI
│   │   └── ... (supporting views)
│   │
│   └── SleanShotCoreTestRunner/     # Core logic tests
│       └── main.swift               # Test runner
│
├── CLAUDE.md                        # Development guidelines
├── HISTORY.md                       # Project milestone log
└── README.md                        # This file
```

### Building

**From Xcode**:
1. Open `SleanShot` in Xcode
2. Select the **SleanShot** target
3. Press Cmd+B to build
4. Press Cmd+R to run

**From command line**:
```bash
# Build the app
xcodebuild -scheme SleanShot -configuration Debug build

# Run the app
xcodebuild -scheme SleanShot -configuration Debug run
```

### Testing

SleanShot includes core logic tests in `SleanShotCoreTestRunner`:

```bash
# Build and run tests
swift test

# Or from Xcode: Product > Test (Cmd+U)
```

Test coverage includes:
- Geometry and area selection logic
- Settings store behavior
- Screenshot and recording flows
- Overlay exclusion verification

## Contributing

We welcome contributions! Here's how to get involved:

### Reporting Issues

Found a bug? Please file an issue with:
- Detailed reproduction steps
- macOS version and Xcode version
- Screenshots or screen recordings if applicable
- Relevant log output from Console.app

### Development Guidelines

Follow these principles when contributing:

1. **Prefer native macOS APIs** over third-party dependencies
2. **Keep components small and focused** on single responsibilities
3. **Maintain Swift 6 concurrency** compatibility (no unsafe patterns)
4. **Do not suppress type errors**—fix them properly
5. **Write testable code** where possible
6. **Keep architectural decisions lightweight** and pragmatic

### Making Changes

1. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following coding guidelines

3. **Test thoroughly**:
   - Build with no warnings: `xcodebuild build`
   - Run existing tests: `swift test`
   - Manually test the app: `xcodebuild run`
   - Test on multiple displays if adding overlay features

4. **Verify MVP scope**:
   - Check `CLAUDE.md` for intended scope
   - Non-MVP features (cloud sync, OCR, etc.) require explicit approval

5. **Commit with clear messages**:
   ```bash
   git commit -m "feat: add feature description"
   ```

6. **Push and open a pull request**:
   ```bash
   git push origin feature/your-feature-name
   ```

### PR Checklist

Before submitting a pull request:

- [ ] Code builds without errors or warnings
- [ ] All tests pass (run `swift test`)
- [ ] Changes follow Swift 6 concurrency guidelines
- [ ] New features are tested on single and multi-monitor setups
- [ ] Documentation is updated (HISTORY.md, code comments)
- [ ] No unrelated refactoring is included
- [ ] Commit messages are clear and descriptive

## Known Issues

See `Bugs.md` for current known issues and workarounds.

### Screen Recording Permission Quirks

**Issue**: Xcode's ad-hoc code signatures change on every rebuild, causing macOS to silently revoke Screen Recording permissions even though System Settings shows "On".

**Workaround**:
1. Open System Settings > Privacy & Security > Screen Recording
2. Remove SleanShot using the minus button
3. Rebuild and launch the app
4. Re-grant Screen Recording permission when prompted

## Architecture Decisions

### Why AppKit NSWindow for Overlays?

SwiftUI-only windows lack precise control over floating behavior, layering, and exclusion from captures. AppKit `NSWindow` provides:
- Borderless, floating windows
- Drag-to-move support
- Precise frame control for multi-monitor
- Integration with ScreenCaptureKit exclusion

### Why PencilKit for Annotation?

PencilKit offers native, low-latency drawing on macOS that users expect. It integrates directly with the OS and doesn't require custom rendering.

### Why Disk Streaming for Recordings?

Screen recordings can exceed available RAM quickly. Writing to disk immediately via `AVAssetWriter` keeps memory usage bounded and prevents data loss if the app crashes.

### Why Exclude Overlays from ScreenCaptureKit?

Rather than rapid show/hide toggles (unreliable and jarring), we configure ScreenCaptureKit's content filter to exclude SleanShot-owned windows. This is reliable and invisible to the user.

## Non-Goals (for MVP)

The following features are out of scope unless explicitly requested:

- Cloud synchronization or storage
- User accounts or authentication
- OCR text extraction
- Capture history or library
- Team sharing or collaboration
- GIF export
- Advanced image editing beyond markup
- Recording annotation or editing
- Upload or share integrations

## Performance Considerations

- **Overlays**: Lightweight floating windows with minimal overhead
- **Recordings**: Streamed to disk immediately; thumbnails generated asynchronously
- **Memory**: Screenshots and annotations kept in memory only as needed
- **Captures**: Instant feedback with pinned overlays
- **Settings**: Live updates without app restart

## Security & Privacy

- **No network access**: All capture and processing is local
- **No tracking**: No telemetry or analytics
- **macOS permissions**: Respects all standard permissions (Screen Recording, file access)
- **Temporary files**: Stored in app-controlled temp directory; cleaned on file drop/delete
- **Clipboard**: Only written when user explicitly copies or auto-copy is enabled

## License

[Add your license information here]

## Support

For questions or issues:

1. Check `CLAUDE.md` for project guidelines
2. Review `HISTORY.md` for recent changes
3. File an issue with detailed reproduction steps
4. Check existing issues for similar problems

## Changelog

See `HISTORY.md` for detailed project milestone and feature logs.

### Recent Updates (2026-05-31)

- No global shortcuts assigned by default — assign your own in Settings
- Added a startup welcome tip explaining shortcut setup (toggleable, reopenable from Settings)
- Added a "Show me how" guide for disabling the macOS screenshot shortcuts, naming the exact entries to uncheck
- Added a one-click "Use macOS shortcuts (⌘⇧3 / ⌘⇧4 / ⌘⇧5)" button

### Recent Updates (2026-05-30)

- Completed MVP roadmap (all 11 steps)
- Added screen recording with full-screen and area support
- Implemented reliable overlay exclusion from captures
- Added settings screen with auto-copy toggle
- Full Swift 6 strict concurrency support
- Comprehensive core logic test suite

---

Made with care for macOS. Contributions welcome.
