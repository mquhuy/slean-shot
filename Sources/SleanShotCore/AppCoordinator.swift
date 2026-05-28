import Foundation

public protocol ClipboardService: AnyObject {
    func copyImageData(_ data: Data)
}

public protocol OverlayManaging: AnyObject {
    func pin(_ item: CaptureItem)
}

public final class AppCoordinator {
    private let settings: SettingsStore
    private let clipboard: ClipboardService
    private let overlays: OverlayManaging

    public init(settings: SettingsStore, clipboard: ClipboardService, overlays: OverlayManaging) {
        self.settings = settings
        self.clipboard = clipboard
        self.overlays = overlays
    }

    @discardableResult
    public func receiveScreenshot(_ imageData: Data) -> CaptureItem {
        let item = CaptureItem.screenshot(imageData: imageData)
        overlays.pin(item)

        if settings.autoCopyScreenshotToClipboard {
            clipboard.copyImageData(imageData)
        }

        return item
    }

    @discardableResult
    public func receiveRecording(fileURL: URL, thumbnailData: Data?) -> CaptureItem {
        let item = CaptureItem.recording(fileURL: fileURL, thumbnailData: thumbnailData)
        overlays.pin(item)
        return item
    }
}
