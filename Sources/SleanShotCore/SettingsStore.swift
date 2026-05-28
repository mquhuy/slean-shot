public struct SettingsStore: Equatable {
    public var autoCopyScreenshotToClipboard: Bool

    public init(autoCopyScreenshotToClipboard: Bool = true) {
        self.autoCopyScreenshotToClipboard = autoCopyScreenshotToClipboard
    }
}
