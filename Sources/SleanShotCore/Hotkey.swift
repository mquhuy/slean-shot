/// Modifier keys for a global hotkey, layout/framework-agnostic. The app layer
/// translates these to Carbon modifier masks for `RegisterEventHotKey`.
public struct HotkeyModifiers: OptionSet, Sendable, Codable, Equatable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let command = HotkeyModifiers(rawValue: 1 << 0)
    public static let shift = HotkeyModifiers(rawValue: 1 << 1)
    public static let option = HotkeyModifiers(rawValue: 1 << 2)
    public static let control = HotkeyModifiers(rawValue: 1 << 3)
}

/// A global keyboard shortcut: a virtual key code plus modifier flags.
public struct Hotkey: Equatable, Sendable, Codable {
    public let keyCode: UInt16
    public let modifiers: HotkeyModifiers

    public init(keyCode: UInt16, modifiers: HotkeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// A sentinel meaning "no shortcut assigned". Has no modifiers, so it is not
    /// `isValid` and is never registered as a global hotkey.
    public static let unset = Hotkey(keyCode: 0, modifiers: [])

    /// At least one modifier is required for a usable global hotkey.
    public var isValid: Bool {
        !modifiers.isEmpty
    }
}

public extension SleanShotCommand {
    /// No shortcut is assigned out of the box — the user opts in via Settings.
    /// `HotkeyStore` returns this whenever a command has no persisted shortcut.
    var defaultHotkey: Hotkey { .unset }

    /// The matching built-in macOS screenshot shortcut, if one exists. These only
    /// take effect once the user disables the corresponding system shortcut, since
    /// macOS gives its own shortcuts priority. Key codes: 3=0x14, 4=0x15, 5=0x17.
    var macOSScreenshotHotkey: Hotkey? {
        switch self {
        case .screenshotFullScreen:
            Hotkey(keyCode: 0x14, modifiers: [.command, .shift]) // ⌘⇧3
        case .screenshotArea:
            Hotkey(keyCode: 0x15, modifiers: [.command, .shift]) // ⌘⇧4
        case .recordArea:
            Hotkey(keyCode: 0x17, modifiers: [.command, .shift]) // ⌘⇧5
        case .recordFullScreen:
            nil // macOS has no distinct full-screen recording shortcut
        }
    }

    /// UserDefaults key under which this command's custom hotkey is persisted.
    var hotkeyDefaultsKey: String {
        "hotkey.\(description)"
    }
}
