import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted to ask the app to open the SwiftUI Settings scene. Handled by a
    /// live SwiftUI view (`MenuBarLabel`) that owns the `openSettings` action.
    static let sleanShotOpenSettings = Notification.Name("sleanShotOpenSettings")
}

/// UserDefaults key controlling whether the welcome tip is shown on launch.
/// Absent key defaults to `true` so the tip appears on first run after install.
let showTipAtStartupKey = "showTipAtStartup"

extension UserDefaults {
    var showTipAtStartup: Bool {
        object(forKey: showTipAtStartupKey) == nil ? true : bool(forKey: showTipAtStartupKey)
    }
}

/// Opens System Settings directly on the Keyboard pane (where the user reaches
/// Keyboard Shortcuts… → Screenshots to disable the system combos).
@MainActor
func openKeyboardShortcutsSettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
        NSWorkspace.shared.open(url)
    }
}

/// Presents a one-time "quick tip" window explaining that SleanShot ships with
/// no shortcuts and how to set them / free up the macOS screenshot combos.
///
/// Shown automatically on launch (unless the user opted out via the in-window
/// toggle) and re-openable from Settings. A shared instance lets both the
/// launch path (`AppServices`) and the Settings screen reach the same window.
@MainActor
final class WelcomeTipPresenter {
    static let shared = WelcomeTipPresenter()

    private var window: NSWindow?

    private init() {}

    /// Shows the tip only if the user hasn't disabled it. Called at launch.
    func showIfEnabled() {
        guard UserDefaults.standard.showTipAtStartup else { return }
        show()
    }

    /// Always shows the tip. Called from Settings' "Show welcome tip" button.
    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let size = NSSize(width: 460, height: 380)
        let panel = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Welcome to SleanShot"
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.center()
        panel.contentView = NSHostingView(rootView: WelcomeTipView { [weak self] in
            self?.hide()
        })
        panel.delegate = windowDelegate
        windowDelegate.onClose = { [weak self] in self?.window = nil }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = panel
    }

    func hide() {
        window?.close()
        window = nil
    }

    private let windowDelegate = TipWindowDelegate()
}

/// Clears the presenter's reference when the user closes the window via its
/// title-bar close button (so a later `show()` rebuilds it cleanly).
private final class TipWindowDelegate: NSObject, NSWindowDelegate {
    var onClose: (() -> Void)?
    func windowWillClose(_ notification: Notification) { onClose?() }
}

/// Presents a step-by-step guide for disabling the built-in macOS screenshot
/// shortcuts so SleanShot's matching combos can take effect. Opened by the
/// "Show me how" buttons in the welcome tip and Settings.
@MainActor
final class HowToDisablePresenter {
    static let shared = HowToDisablePresenter()

    private var window: NSWindow?
    private let windowDelegate = TipWindowDelegate()

    private init() {}

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 540),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Disable macOS Screenshot Shortcuts"
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.center()
        panel.contentView = NSHostingView(rootView: HowToDisableView { [weak self] in
            self?.hide()
        })
        panel.delegate = windowDelegate
        windowDelegate.onClose = { [weak self] in self?.window = nil }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = panel
    }

    func hide() {
        window?.close()
        window = nil
    }
}

private struct HowToDisableView: View {
    let onDismiss: () -> Void

    private let steps: [String] = [
        "Open System Settings, then go to Keyboard.",
        "Click the “Keyboard Shortcuts…” button.",
        "Select “Screenshots” in the left sidebar.",
        "Uncheck these three entries, then click Done:",
        "Back in SleanShot Settings → Global Shortcuts, assign those combos — or use the “Use macOS shortcuts” button. They take effect immediately."
    ]

    /// The exact rows to uncheck in the macOS Screenshots pane, with the combo
    /// and what SleanShot uses each for.
    private let entriesToDisable: [(combo: String, name: String, use: String)] = [
        ("⌘⇧3", "Save picture of screen as a file", "Screenshot Full Screen"),
        ("⌘⇧4", "Save picture of selected area as a file", "Screenshot Area"),
        ("⌘⇧5", "Screenshot and recording options", "Record Area")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Free up the macOS screenshot keys")
                    .font(.title3.weight(.semibold))
                Text("macOS reserves ⌘⇧3 / ⌘⇧4 / ⌘⇧5 and they override apps. Turn off the ones you want SleanShot to use.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.accentColor))
                        Text(step)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // The explicit entry list belongs under step 4 ("Uncheck these…").
                    if index == 3 {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(entriesToDisable, id: \.combo) { entry in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(entry.combo)
                                        .font(.callout.monospaced().weight(.semibold))
                                        .frame(width: 44, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("“\(entry.name)”")
                                            .font(.callout)
                                        Text("→ SleanShot \(entry.use)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.leading, 30)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Button("Open Keyboard Settings…") {
                    openKeyboardShortcutsSettings()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                Button("Done") { onDismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}

private struct WelcomeTipView: View {
    let onDismiss: () -> Void
    @AppStorage(showTipAtStartupKey) private var showAtStartup = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 30))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick tip: keyboard shortcuts")
                        .font(.title3.weight(.semibold))
                    Text("SleanShot starts with no shortcuts set.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                tipRow(number: "1", text: "macOS reserves ⌘⇧3 / ⌘⇧4 / ⌘⇧5 for its own screenshots. To reuse those combos in SleanShot, turn them off in System Settings first.")
                tipRow(number: "2", text: "Pick your own shortcuts for each capture in SleanShot Settings → Global Shortcuts. Click a field and press the keys.")
            }

            HStack(spacing: 10) {
                Button("Show me how") {
                    HowToDisablePresenter.shared.show()
                }
                Button("Set My Shortcuts…") {
                    onDismiss()
                    NotificationCenter.default.post(name: .sleanShotOpenSettings, object: nil)
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            Toggle("Open this at startup", isOn: $showAtStartup)
                .font(.callout)
            Text("You can reopen this tip anytime from Settings.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Spacer()
                Button("Got it") { onDismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func tipRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
