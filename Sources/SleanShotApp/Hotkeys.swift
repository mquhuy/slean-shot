import AppKit
import Carbon.HIToolbox
import Foundation
import OSLog
import SwiftUI
import SleanShotCore

private let hotkeyLogger = Logger(subsystem: "com.huy.SleanShot", category: "Hotkeys")

/// Notification posted when a hotkey is changed in Settings so the running
/// `GlobalHotkeyManager` can re-register.
extension Notification.Name {
    static let sleanShotHotkeysChanged = Notification.Name("sleanShotHotkeysChanged")
}

// MARK: - Persistence

enum HotkeyStore {
    static func hotkey(for command: SleanShotCommand, defaults: UserDefaults = .standard) -> Hotkey {
        guard let data = defaults.data(forKey: command.hotkeyDefaultsKey),
              let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return command.defaultHotkey
        }
        return hotkey
    }

    static func setHotkey(_ hotkey: Hotkey, for command: SleanShotCommand, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: command.hotkeyDefaultsKey)
        }
        NotificationCenter.default.post(name: .sleanShotHotkeysChanged, object: nil)
    }

    static func reset(_ command: SleanShotCommand, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: command.hotkeyDefaultsKey)
        NotificationCenter.default.post(name: .sleanShotHotkeysChanged, object: nil)
    }

    /// Assigns each command its matching built-in macOS screenshot shortcut
    /// (⌘⇧3 / ⌘⇧4 / ⌘⇧5). Commands without a macOS equivalent are left untouched.
    /// These only fire once the user disables the system shortcuts.
    static func applyMacOSDefaults(defaults: UserDefaults = .standard) {
        for command in SleanShotCommand.menuCommands {
            guard let hotkey = command.macOSScreenshotHotkey,
                  let data = try? JSONEncoder().encode(hotkey) else { continue }
            defaults.set(data, forKey: command.hotkeyDefaultsKey)
        }
        NotificationCenter.default.post(name: .sleanShotHotkeysChanged, object: nil)
    }
}

// MARK: - Display strings

enum HotkeyFormatter {
    static func string(for hotkey: Hotkey) -> String {
        guard hotkey.isValid else { return "Not set" }
        return modifierString(hotkey.modifiers) + keyString(hotkey.keyCode)
    }

    static func modifierString(_ mods: HotkeyModifiers) -> String {
        var s = ""
        if mods.contains(.control) { s += "⌃" }
        if mods.contains(.option) { s += "⌥" }
        if mods.contains(.shift) { s += "⇧" }
        if mods.contains(.command) { s += "⌘" }
        return s
    }

    static func keyString(_ keyCode: UInt16) -> String {
        if let special = specialKeys[Int(keyCode)] { return special }
        // Map the virtual key code to a character via the current layout.
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "?"
        }
        let data = unsafeBitCast(layoutData, to: CFData.self)
        let keyLayoutPtr = CFDataGetBytePtr(data)
        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let result = keyLayoutPtr?.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layout in
            UCKeyTranslate(
                layout,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }
        guard result == noErr, length > 0 else { return "?" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space",
        kVK_Return: "↩",
        kVK_Tab: "⇥",
        kVK_Escape: "⎋",
        kVK_Delete: "⌫",
        kVK_LeftArrow: "←",
        kVK_RightArrow: "→",
        kVK_UpArrow: "↑",
        kVK_DownArrow: "↓"
    ]
}

// MARK: - Carbon translation

private func carbonModifiers(_ mods: HotkeyModifiers) -> UInt32 {
    var flags: UInt32 = 0
    if mods.contains(.command) { flags |= UInt32(cmdKey) }
    if mods.contains(.shift) { flags |= UInt32(shiftKey) }
    if mods.contains(.option) { flags |= UInt32(optionKey) }
    if mods.contains(.control) { flags |= UInt32(controlKey) }
    return flags
}

// MARK: - Global hotkey manager

/// Registers system-wide hotkeys via Carbon `RegisterEventHotKey` (fires from
/// any app, no extra permission needed) and dispatches presses to actions.
@MainActor
final class GlobalHotkeyManager {
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1
    private let signature: OSType = 0x534C_4E53 // 'SLNS'

    func reload(actionProvider: @escaping (SleanShotCommand) -> Void) {
        unregisterAll()
        installHandlerIfNeeded()
        for command in SleanShotCommand.menuCommands {
            let hotkey = HotkeyStore.hotkey(for: command)
            guard hotkey.isValid else { continue }
            register(hotkey) { actionProvider(command) }
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                // Carbon hotkey events are delivered on the main thread/run loop,
                // so we are already on the MainActor executor here.
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated {
                    manager.fire(id: hotKeyID.id)
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }

    private func register(_ hotkey: Hotkey, action: @escaping () -> Void) {
        let id = nextID
        nextID += 1
        actions[id] = action

        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(hotkey.keyCode),
            carbonModifiers(hotkey.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRefs.append(ref)
        } else {
            hotkeyLogger.error("RegisterEventHotKey failed status=\(status) keyCode=\(hotkey.keyCode)")
            actions[id] = nil
        }
    }

    private func fire(id: UInt32) {
        actions[id]?()
    }

    func unregisterAll() {
        for case let ref? in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        actions.removeAll()
        nextID = 1
    }
}

// MARK: - SwiftUI recorder field

/// A click-to-record field that captures the next key combo as a `Hotkey`.
struct HotkeyRecorderField: NSViewRepresentable {
    let command: SleanShotCommand
    @Binding var hotkey: Hotkey

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onCapture = { newHotkey in
            hotkey = newHotkey
            HotkeyStore.setHotkey(newHotkey, for: command)
        }
        view.hotkey = hotkey
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.hotkey = hotkey
        nsView.needsDisplay = true
    }

    final class RecorderView: NSView {
        var hotkey: Hotkey = Hotkey(keyCode: 0, modifiers: [])
        var onCapture: ((Hotkey) -> Void)?
        private var recording = false

        override var acceptsFirstResponder: Bool { true }
        override var intrinsicContentSize: NSSize { NSSize(width: 140, height: 24) }

        override func draw(_ dirtyRect: NSRect) {
            let bg = recording ? NSColor.controlAccentColor.withAlphaComponent(0.2) : NSColor.controlBackgroundColor
            bg.setFill()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
            path.fill()
            NSColor.separatorColor.setStroke()
            path.stroke()

            let placeholder = recording || !hotkey.isValid
            let text = recording ? "Type shortcut…" : HotkeyFormatter.string(for: hotkey)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: placeholder ? NSColor.secondaryLabelColor : NSColor.labelColor
            ]
            let size = text.size(withAttributes: attrs)
            text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attrs)
        }

        override func mouseDown(with event: NSEvent) {
            recording = true
            window?.makeFirstResponder(self)
            needsDisplay = true
        }

        override func keyDown(with event: NSEvent) {
            guard recording else { super.keyDown(with: event); return }
            if event.keyCode == UInt16(kVK_Escape) {
                recording = false
                needsDisplay = true
                return
            }
            var mods: HotkeyModifiers = []
            if event.modifierFlags.contains(.command) { mods.insert(.command) }
            if event.modifierFlags.contains(.shift) { mods.insert(.shift) }
            if event.modifierFlags.contains(.option) { mods.insert(.option) }
            if event.modifierFlags.contains(.control) { mods.insert(.control) }

            guard !mods.isEmpty else { return } // require at least one modifier
            let newHotkey = Hotkey(keyCode: event.keyCode, modifiers: mods)
            hotkey = newHotkey
            recording = false
            needsDisplay = true
            onCapture?(newHotkey)
        }

        override func resignFirstResponder() -> Bool {
            recording = false
            needsDisplay = true
            return super.resignFirstResponder()
        }
    }
}
