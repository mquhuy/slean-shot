import AppKit
import SwiftUI
import SleanShotCore

@main
struct SleanShotApp: App {
    @StateObject private var services = AppServices()

    var body: some Scene {
        MenuBarExtra {
            Text("SleanShot")
            Divider()

            ForEach(SleanShotCommand.menuCommands, id: \.self) { command in
                Button(command.title) {
                    services.perform(command)
                }
                .disabled(services.isRecording && command.isRecording)
            }

            if services.isRecording {
                Divider()
                Button("Stop Recording") {
                    services.stopRecording()
                }
            }

            Divider()
            Button("Settings") {
                NotificationCenter.default.post(name: .sleanShotOpenSettings, object: nil)
            }
            Button("Quit") {
                services.quit()
            }
            .keyboardShortcut("q")
        } label: {
            // A persistent label view so the `openSettings` bridge stays alive
            // even while the menu is closed.
            MenuBarLabel()
        }

        Settings {
            SettingsView()
        }
    }
}

/// Menu-bar icon plus a bridge that lets non-SwiftUI windows (the welcome tip)
/// open the Settings scene: the only supported way to open Settings on macOS 14
/// is the `openSettings` environment action, which requires a live SwiftUI view.
private struct MenuBarLabel: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image("MenuBarIcon")
            .renderingMode(.template)
            .onReceive(NotificationCenter.default.publisher(for: .sleanShotOpenSettings)) { _ in
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
                // Settings scene window can open behind other apps' windows; force it
                // above everything once SwiftUI has created/shown it.
                Task { @MainActor in
                    raiseSettingsWindow()
                }
            }
    }
}

/// Brings the SwiftUI Settings scene window in front of all other windows.
/// The Settings scene gives us no direct window reference, so locate it among
/// `NSApp.windows`. SwiftUI tags it with a "Settings" identifier on macOS 14+;
/// fall back to the title for older shapes.
@MainActor
private func raiseSettingsWindow() {
    let settingsWindow = NSApp.windows.first { window in
        let id = window.identifier?.rawValue ?? ""
        return id.contains("Settings") || window.title == "Settings"
    }
    guard let settingsWindow else { return }
    settingsWindow.makeKeyAndOrderFront(nil)
    settingsWindow.orderFrontRegardless()
}
