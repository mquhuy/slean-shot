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
            SettingsLink {
                Text("Settings")
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
        Image(systemName: "camera.viewfinder")
            .onReceive(NotificationCenter.default.publisher(for: .sleanShotOpenSettings)) { _ in
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
    }
}
