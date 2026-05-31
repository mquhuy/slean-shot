import SwiftUI
import SleanShotCore

struct SettingsView: View {
    @AppStorage("autoCopyScreenshotToClipboard") private var autoCopyScreenshotToClipboard = true
    @AppStorage("showRecordingBorder") private var showRecordingBorder = true
    @AppStorage(showTipAtStartupKey) private var showTipAtStartup = true

    @State private var hotkeys: [SleanShotCommand: Hotkey] = [:]

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Image("Logo")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(height: 40)
                        .accessibilityLabel("SleanShot")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("General") {
                Toggle("Automatically copy screenshots to clipboard", isOn: $autoCopyScreenshotToClipboard)
                Toggle("Show a border around the recording area", isOn: $showRecordingBorder)
            }

            Section("Global Shortcuts") {
                ForEach(SleanShotCommand.menuCommands, id: \.self) { command in
                    HStack {
                        Text(command.title)
                        Spacer()
                        HotkeyRecorderField(command: command, hotkey: binding(for: command))
                            .frame(width: 140, height: 24)
                        Button {
                            HotkeyStore.reset(command)
                            hotkeys[command] = command.defaultHotkey
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Clear shortcut")
                    }
                }
                Text("No shortcuts are set by default. Click a field and press a key combination; it works system-wide. Use the ✕ to clear one.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("macOS Screenshot Shortcuts") {
                Text("macOS reserves ⌘⇧3 / ⌘⇧4 / ⌘⇧5 for its own screenshots and they take priority over apps. Disable them first, then you can assign the same combos to SleanShot.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Show me how to disable them") {
                    HowToDisablePresenter.shared.show()
                }
                Button("Use macOS shortcuts (⌘⇧3 / ⌘⇧4 / ⌘⇧5)") {
                    HotkeyStore.applyMacOSDefaults()
                    loadHotkeys()
                }
            }

            Section("Welcome Tip") {
                Toggle("Show the welcome tip at startup", isOn: $showTipAtStartup)
                Button("Show Welcome Tip Now") {
                    WelcomeTipPresenter.shared.show()
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
        .onAppear(perform: loadHotkeys)
    }

    private func loadHotkeys() {
        for command in SleanShotCommand.menuCommands {
            hotkeys[command] = HotkeyStore.hotkey(for: command)
        }
    }

    private func binding(for command: SleanShotCommand) -> Binding<Hotkey> {
        Binding(
            get: { hotkeys[command] ?? command.defaultHotkey },
            set: { hotkeys[command] = $0 }
        )
    }
}
