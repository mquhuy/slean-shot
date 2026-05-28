# Menu Bar App Shell Design

## Purpose

The next implementation slice creates SleanShot's first runnable macOS app shell. The app should behave like a lightweight screenshot utility: always available from the menu bar, mostly out of the user's way, and ready to connect capture, permission, overlay, and settings features incrementally.

This slice does not implement real ScreenCaptureKit capture yet. It establishes the native app entry point and the UI surface where capture commands will live.

## Decision

Use a menu bar first app.

Rejected alternatives:

- Normal main window first: useful for dashboard/history apps, but SleanShot's MVP has no history library and should stay unobtrusive.
- Menu bar plus permanent window: more UI than needed for MVP and adds window lifecycle complexity before capture works.

The menu bar app should provide quick actions and open settings only when requested.

## User Interface

The menu bar item should expose these actions:

- Screenshot Area
- Screenshot Full Screen
- Record Area
- Record Full Screen
- Settings
- Quit

Settings should open a small SwiftUI window containing the existing MVP setting:

- Automatically copy screenshots to clipboard

For this slice, capture/record actions may route to placeholders or coordinator methods that can be replaced by real engines later. They should not pretend to capture media if ScreenCaptureKit is not wired yet.

## Architecture

Add an app-shell layer that depends on `SleanShotCore` instead of moving app logic into SwiftUI views.

Suggested boundary:

```text
SleanShotApp
├── SleanShotApp.swift
├── SwiftUI MenuBarExtra scene
├── SettingsView
└── AppServices
    ├── AppCoordinator
    ├── Clipboard adapter
    └── Overlay adapter placeholder
```

Keep `SleanShotCore` focused on testable behavior:

- Capture item model
- Settings model/persistence boundary
- Coordinator behavior
- Protocols for clipboard, overlays, and future capture engines

The app target owns macOS-specific adapters such as `NSPasteboard`, SwiftUI settings UI, and future AppKit overlay windows.

Use SwiftUI `MenuBarExtra` for the first app shell because the package targets macOS 14+. Drop to an AppKit `NSStatusItem` only if `MenuBarExtra` blocks a concrete MVP behavior.

## Data Flow

Menu action flow:

```text
User chooses menu item
→ App shell calls an app service/coordinator method
→ Placeholder action reports unavailable capture until engines exist
→ Later replacement calls CaptureEngine or RecordingEngine
```

Settings flow:

```text
User opens Settings
→ SwiftUI SettingsView reads/writes persisted setting
→ AppCoordinator receives current SettingsStore when handling capture results
```

The exact persistence adapter can be minimal in this slice. Prefer `@AppStorage` for the SwiftUI settings control and keep the core `SettingsStore` value type for coordinator decisions.

## Error Handling

Capture and recording menu actions should have honest placeholder behavior until ScreenCaptureKit is implemented. Acceptable behavior:

- Disabled menu items with labels indicating they are coming next.
- Enabled items that show a small alert explaining capture is not implemented yet.

Do not add fake screenshots or recordings just to exercise overlays. Testable coordinator behavior already covers receiving captured media.

## Testing

Continue using TDD for testable core changes.

For this slice:

- Add tests first if any new coordinator/settings behavior is introduced.
- Build the Swift package/app target from the command line.
- Keep UI code thin enough that most behavior remains in `SleanShotCore`.

Manual verification after implementation:

- App launches.
- Menu bar item appears.
- Menu contains the expected actions.
- Settings opens.
- Auto-copy setting can be toggled.
- Quit exits the app.

## Repository Hygiene

Ignore SwiftPM/Xcode local workspace state generated under `.swiftpm/`. These files are developer-local and should not be committed.

## Out Of Scope

- Real screenshot capture
- Real screen recording
- Area selection UI
- Pinned overlay windows
- Overlay exclusion
- Annotation editor
- Global keyboard shortcuts
- Capture history
