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
                .keyboardShortcut(KeyEquivalent(command.keyEquivalent), modifiers: [.command, .control])
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
