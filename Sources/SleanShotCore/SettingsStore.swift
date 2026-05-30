/// Read-only view of the settings the coordinator needs at capture time.
///
/// The coordinator must read the *current* value every time it captures, so the
/// app provides a live, `UserDefaults`-backed implementation while tests pass a
/// fixed `SettingsStore` snapshot.
public protocol SettingsProviding: Sendable {
    var autoCopyScreenshotToClipboard: Bool { get }
}

public struct SettingsStore: SettingsProviding, Equatable {
    public var autoCopyScreenshotToClipboard: Bool

    public init(autoCopyScreenshotToClipboard: Bool = true) {
        self.autoCopyScreenshotToClipboard = autoCopyScreenshotToClipboard
    }
}
