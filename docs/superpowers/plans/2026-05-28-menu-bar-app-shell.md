# Menu Bar App Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build SleanShot's first runnable macOS menu bar app shell with placeholder capture actions and a settings window.

**Architecture:** Keep testable behavior in `SleanShotCore`, then add a separate `SleanShotApp` executable target for SwiftUI/AppKit UI and adapters. The app target uses SwiftUI `MenuBarExtra` for quick actions, `Settings` for the settings window, and small app services for placeholder capture commands.

**Tech Stack:** Swift 6 package, SwiftUI, AppKit, `@AppStorage`, existing executable test runner.

---

## File Structure

- Modify `Package.swift`: add the `SleanShotApp` executable product and target.
- Modify `Sources/SleanShotCoreTestRunner/main.swift`: add tests for menu command labels and placeholder-eligible commands.
- Create `Sources/SleanShotCore/SleanShotCommand.swift`: testable command definitions shared by the app menu.
- Create `Sources/SleanShotApp/SleanShotApp.swift`: SwiftUI `@main` app with `MenuBarExtra` and `Settings` scene.
- Create `Sources/SleanShotApp/SettingsView.swift`: settings UI backed by `@AppStorage`.
- Create `Sources/SleanShotApp/AppServices.swift`: placeholder command handling plus app adapters for clipboard/overlay protocols.

## Task 1: Add Testable Menu Commands

**Files:**
- Modify: `Sources/SleanShotCoreTestRunner/main.swift`
- Create: `Sources/SleanShotCore/SleanShotCommand.swift`

- [ ] **Step 1: Write the failing test**

Add these tests after `testSettingsDefaultToAutoCopyScreenshotsEnabled()` in `Sources/SleanShotCoreTestRunner/main.swift`:

```swift
func testMenuCommandsExposeExpectedTitles() {
    let titles = SleanShotCommand.menuCommands.map(\.title)

    expect(
        titles == [
            "Screenshot Area",
            "Screenshot Full Screen",
            "Record Area",
            "Record Full Screen"
        ],
        "Menu commands should expose capture and recording actions in MVP order"
    )
}

func testCaptureCommandsAreUnavailableUntilEnginesExist() {
    let unavailableMessages = SleanShotCommand.menuCommands.map(\.unavailableMessage)

    expect(
        unavailableMessages == [
            "Area screenshots are not implemented yet.",
            "Full-screen screenshots are not implemented yet.",
            "Area recording is not implemented yet.",
            "Full-screen recording is not implemented yet."
        ],
        "Menu commands should be honest placeholders until capture engines exist"
    )
}
```

Call them near the bottom of the same file before `print("SleanShotCoreTestRunner passed")`:

```swift
testMenuCommandsExposeExpectedTitles()
testCaptureCommandsAreUnavailableUntilEnginesExist()
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift run SleanShotCoreTestRunner
```

Expected: FAIL to compile with `cannot find 'SleanShotCommand' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Sources/SleanShotCore/SleanShotCommand.swift`:

```swift
public enum SleanShotCommand: CaseIterable, Equatable {
    case screenshotArea
    case screenshotFullScreen
    case recordArea
    case recordFullScreen

    public static let menuCommands: [SleanShotCommand] = [
        .screenshotArea,
        .screenshotFullScreen,
        .recordArea,
        .recordFullScreen
    ]

    public var title: String {
        switch self {
        case .screenshotArea:
            "Screenshot Area"
        case .screenshotFullScreen:
            "Screenshot Full Screen"
        case .recordArea:
            "Record Area"
        case .recordFullScreen:
            "Record Full Screen"
        }
    }

    public var unavailableMessage: String {
        switch self {
        case .screenshotArea:
            "Area screenshots are not implemented yet."
        case .screenshotFullScreen:
            "Full-screen screenshots are not implemented yet."
        case .recordArea:
            "Area recording is not implemented yet."
        case .recordFullScreen:
            "Full-screen recording is not implemented yet."
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift run SleanShotCoreTestRunner
```

Expected: PASS with `SleanShotCoreTestRunner passed`.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/SleanShotCore/SleanShotCommand.swift Sources/SleanShotCoreTestRunner/main.swift
git commit -m "feat(core): add app menu commands"
```

## Task 2: Add App Executable Target

**Files:**
- Modify: `Package.swift`
- Create: `Sources/SleanShotApp/SleanShotApp.swift`

- [ ] **Step 1: Run build to verify the app target is missing**

Run:

```bash
swift build --product SleanShotApp
```

Expected: FAIL with `no product named 'SleanShotApp'` or equivalent missing product output.

- [ ] **Step 2: Write the minimal app entry point**

Create `Sources/SleanShotApp/SleanShotApp.swift`:

```swift
import SwiftUI

@main
struct SleanShotApp: App {
    var body: some Scene {
        MenuBarExtra("SleanShot", systemImage: "camera.viewfinder") {
            Text("SleanShot")
        }
    }
}
```

- [ ] **Step 3: Add the executable product and target**

Update `Package.swift` to this complete content:

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SleanShot",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SleanShotCore",
            targets: ["SleanShotCore"]
        ),
        .executable(
            name: "SleanShotApp",
            targets: ["SleanShotApp"]
        ),
        .executable(
            name: "SleanShotCoreTestRunner",
            targets: ["SleanShotCoreTestRunner"]
        )
    ],
    targets: [
        .target(
            name: "SleanShotCore"
        ),
        .executableTarget(
            name: "SleanShotApp",
            dependencies: ["SleanShotCore"]
        ),
        .executableTarget(
            name: "SleanShotCoreTestRunner",
            dependencies: ["SleanShotCore"]
        )
    ]
)
```

- [ ] **Step 4: Build the app target**

Run:

```bash
swift build --product SleanShotApp
```

Expected: build completes successfully.

- [ ] **Step 5: Run existing tests**

Run:

```bash
swift run SleanShotCoreTestRunner
```

Expected: PASS with `SleanShotCoreTestRunner passed`.

- [ ] **Step 6: Commit**

Run:

```bash
git add Package.swift Sources/SleanShotApp/SleanShotApp.swift
git commit -m "feat(app): add menu bar executable"
```

## Task 3: Add Placeholder App Services

**Files:**
- Create: `Sources/SleanShotApp/AppServices.swift`

- [ ] **Step 1: Create app services**

Create `Sources/SleanShotApp/AppServices.swift`:

```swift
import AppKit
import Combine
import Foundation
import SleanShotCore

@MainActor
protocol AlertPresenting: AnyObject {
    func show(message: String)
}

@MainActor
final class NSAlertPresenter: AlertPresenting {
    func show(message: String) {
        let alert = NSAlert()
        alert.messageText = "SleanShot"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

@MainActor
final class AppServices: ObservableObject {
    private let alertPresenter: AlertPresenting

    init(alertPresenter: AlertPresenting = NSAlertPresenter()) {
        self.alertPresenter = alertPresenter
    }

    func perform(_ command: SleanShotCommand) {
        alertPresenter.show(message: command.unavailableMessage)
    }

    func quit() {
        NSApp.terminate(nil)
    }
}

final class AppClipboardService: ClipboardService {
    func copyImageData(_ data: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .png)
    }
}

final class PlaceholderOverlayManager: OverlayManaging {
    func pin(_ item: CaptureItem) {
        // Real AppKit overlay windows are added in a later slice.
    }
}
```

- [ ] **Step 2: Build the app target**

Run:

```bash
swift build --product SleanShotApp
```

Expected: build completes successfully.

- [ ] **Step 3: Run existing tests**

Run:

```bash
swift run SleanShotCoreTestRunner
```

Expected: PASS with `SleanShotCoreTestRunner passed`.

- [ ] **Step 4: Commit**

Run:

```bash
git add Sources/SleanShotApp/AppServices.swift
git commit -m "feat(app): add placeholder services"
```

## Task 4: Add Settings Window

**Files:**
- Create: `Sources/SleanShotApp/SettingsView.swift`
- Modify: `Sources/SleanShotApp/SleanShotApp.swift`

- [ ] **Step 1: Create the settings view**

Create `Sources/SleanShotApp/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @AppStorage("autoCopyScreenshotToClipboard") private var autoCopyScreenshotToClipboard = true

    var body: some View {
        Form {
            Toggle("Automatically copy screenshots to clipboard", isOn: $autoCopyScreenshotToClipboard)
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }
}

#Preview {
    SettingsView()
}
```

- [ ] **Step 2: Register the Settings scene**

Update `Sources/SleanShotApp/SleanShotApp.swift` to this complete content:

```swift
import SwiftUI
import SleanShotCore

@main
struct SleanShotApp: App {
    @StateObject private var services = AppServices()

    var body: some Scene {
        MenuBarExtra("SleanShot", systemImage: "camera.viewfinder") {
            Text("SleanShot")
            Divider()

            ForEach(SleanShotCommand.menuCommands, id: \.self) { command in
                Button(command.title) {
                    services.perform(command)
                }
            }

            Divider()
            SettingsLink {
                Text("Settings")
            }
            Button("Quit") {
                services.quit()
            }
            .keyboardShortcut("q")
        }

        Settings {
            SettingsView()
        }
    }
}
```

- [ ] **Step 3: Build the app target**

Run:

```bash
swift build --product SleanShotApp
```

Expected: build completes successfully.

- [ ] **Step 4: Run existing tests**

Run:

```bash
swift run SleanShotCoreTestRunner
```

Expected: PASS with `SleanShotCoreTestRunner passed`.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/SleanShotApp/SleanShotApp.swift Sources/SleanShotApp/SettingsView.swift
git commit -m "feat(app): add settings window"
```

## Task 5: Manual App Verification

**Files:**
- No code changes expected.

- [ ] **Step 1: Launch the app from SwiftPM**

Run:

```bash
swift run SleanShotApp
```

Expected: the command launches a macOS process and a SleanShot menu bar item appears.

- [ ] **Step 2: Verify menu contents**

Open the menu bar item.

Expected visible items:

```text
SleanShot
Screenshot Area
Screenshot Full Screen
Record Area
Record Full Screen
Settings
Quit
```

- [ ] **Step 3: Verify placeholder capture actions**

Choose each capture/record menu item.

Expected: an informational alert appears with the corresponding message from `SleanShotCommand.unavailableMessage`.

- [ ] **Step 4: Verify Settings**

Choose `Settings`.

Expected: settings window opens and contains `Automatically copy screenshots to clipboard`.

- [ ] **Step 5: Verify Quit**

Choose `Quit`.

Expected: the app exits and the `swift run SleanShotApp` command returns.

- [ ] **Step 6: Final automated verification**

Run:

```bash
swift build
swift run SleanShotCoreTestRunner
git status --short --ignored
```

Expected:

```text
Build complete!
SleanShotCoreTestRunner passed
```

`git status --short --ignored` may show ignored local files such as `.agents/`, `.build/`, `.swiftpm/`, and `skills-lock.json`. It should not show unstaged tracked changes.
