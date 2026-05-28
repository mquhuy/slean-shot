import Foundation

public protocol ClipboardService: Sendable {
    func copyImageData(_ data: Data)
}

public protocol OverlayManaging: Sendable {
    @MainActor func pin(_ item: CaptureItem)
}

public actor AppCoordinator {
    private let settings: SettingsStore
    private let clipboard: ClipboardService
    private let overlays: OverlayManaging
    private let permissionManager: PermissionManaging
    private let captureEngine: CaptureEngine

    public init(
        settings: SettingsStore,
        clipboard: ClipboardService,
        overlays: OverlayManaging,
        permissionManager: PermissionManaging,
        captureEngine: CaptureEngine
    ) {
        self.settings = settings
        self.clipboard = clipboard
        self.overlays = overlays
        self.permissionManager = permissionManager
        self.captureEngine = captureEngine
    }

    public func handle(_ command: SleanShotCommand) async throws {
        switch command {
        case .screenshotFullScreen:
            guard permissionManager.hasScreenCaptureAccess else {
                _ = await permissionManager.requestScreenCaptureAccess()
                throw CaptureError.permissionDenied
            }
            
            let data = try await captureEngine.captureFullScreen()
            try? data.write(to: URL(fileURLWithPath: ("/Users/huy/Desktop/debug_screenshot.png")))
            await receiveScreenshot(data)
            
        case .screenshotArea, .recordArea, .recordFullScreen:
            throw CaptureError.captureFailed(command.unavailableMessage)
        }
    }

    @discardableResult
    public func receiveScreenshot(_ imageData: Data) async -> CaptureItem {
        let item = CaptureItem.screenshot(imageData: imageData)
        await overlays.pin(item)

        if settings.autoCopyScreenshotToClipboard {
            clipboard.copyImageData(imageData)
        }

        return item
    }
    
    @discardableResult
    public func receiveRecording(fileURL: URL, thumbnailData: Data?) async -> CaptureItem {
        let item = CaptureItem.recording(fileURL: fileURL, thumbnailData: thumbnailData)
        await overlays.pin(item)
        return item
    }
}