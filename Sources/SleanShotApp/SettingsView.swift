import AppKit
import SwiftUI
import SleanShotCore

struct SettingsView: View {
    @AppStorage("autoCopyScreenshotToClipboard") private var autoCopyScreenshotToClipboard = true
    @AppStorage("showRecordingBorder") private var showRecordingBorder = true
    @AppStorage(excludeSleanShotFromCapturesKey) private var excludeSleanShotFromCaptures = true
    @AppStorage(showTipAtStartupKey) private var showTipAtStartup = true
    @AppStorage(defaultScreenshotDirectoryKey) private var defaultScreenshotDirectory = ""
    @AppStorage(autoSaveScreenshotsKey) private var autoSaveScreenshots = false

    @State private var hotkeys: [SleanShotCommand: Hotkey] = [:]
    @State private var launchAtLogin = LoginItemService.isEnabled

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
                Toggle("Start SleanShot at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
                Toggle("Automatically copy screenshots to clipboard", isOn: $autoCopyScreenshotToClipboard)
                Toggle("Show a border around the recording area", isOn: $showRecordingBorder)
                Toggle("Hide SleanShot windows from screenshots and recordings", isOn: $excludeSleanShotFromCaptures)
            }

            Section("Screenshots") {
                HStack {
                    Text("Default save location")
                    Spacer()
                    Text(saveLocationLabel)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Choose…", action: chooseSaveLocation)
                    if !defaultScreenshotDirectory.isEmpty {
                        Button {
                            defaultScreenshotDirectory = ""
                            autoSaveScreenshots = false
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Ask each time")
                    }
                }
                Text("New screenshots are named like macOS (e.g. “Screenshot 2026-05-31 at 14.30.45.png”). When no folder is set, the save dialog asks each time.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Save automatically without asking", isOn: $autoSaveScreenshots)
                    .disabled(defaultScreenshotDirectory.isEmpty)
                Text("Writes each screenshot straight to the save location with a timestamped name. Requires a default save location.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

    private var saveLocationLabel: String {
        defaultScreenshotDirectory.isEmpty
            ? "Ask each time"
            : URL(fileURLWithPath: defaultScreenshotDirectory).lastPathComponent
    }

    private func chooseSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if !defaultScreenshotDirectory.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: defaultScreenshotDirectory)
        }
        if panel.runModal() == .OK, let url = panel.url {
            defaultScreenshotDirectory = url.path
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemService.setEnabled(enabled)
        } catch {
            // Revert the toggle to the real system state on failure.
            launchAtLogin = LoginItemService.isEnabled
            let alert = NSAlert()
            alert.messageText = "Couldn’t update “Start at login”."
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
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
