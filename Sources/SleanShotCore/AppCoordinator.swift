import Foundation

public protocol ClipboardService: Sendable {
    func copyImageData(_ data: Data)
}

public protocol OverlayManaging: Sendable {
    @MainActor func pin(_ item: CaptureItem, actions: OverlayActions)
    @MainActor func remove(_ id: UUID)
}

public actor AppCoordinator {
    private let settings: SettingsStore
    private let clipboard: ClipboardService
    private let overlays: OverlayManaging
    private let fileExport: FileExportService
    private let permissionManager: PermissionManaging
    private let captureEngine: CaptureEngine

    public init(
        settings: SettingsStore,
        clipboard: ClipboardService,
        overlays: OverlayManaging,
        fileExport: FileExportService,
        permissionManager: PermissionManaging,
        captureEngine: CaptureEngine
    ) {
        self.settings = settings
        self.clipboard = clipboard
        self.overlays = overlays
        self.fileExport = fileExport
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
            await receiveScreenshot(data)
            
        case .screenshotArea, .recordArea, .recordFullScreen:
            throw CaptureError.captureFailed(command.unavailableMessage)
        }
    }

    @discardableResult
    public func receiveScreenshot(_ imageData: Data) async -> CaptureItem {
        let item = CaptureItem.screenshot(imageData: imageData)
        let actions = OverlayActions(
            copy: { [clipboard] in
                clipboard.copyImageData(imageData)
            },
            save: { [fileExport] in
                fileExport.saveImageData(imageData)
            },
            drop: { [overlays, id = item.id] in
                overlays.remove(id)
            }
        )

        await overlays.pin(item, actions: actions)

        if settings.autoCopyScreenshotToClipboard {
            clipboard.copyImageData(imageData)
        }

        return item
    }
    
    @discardableResult
    public func receiveRecording(fileURL: URL, thumbnailData: Data?) async -> CaptureItem {
        let item = CaptureItem.recording(fileURL: fileURL, thumbnailData: thumbnailData)
        let actions = OverlayActions(
            copy: {},
            save: {},
            drop: { [overlays, id = item.id] in
                overlays.remove(id)
            }
        )

        await overlays.pin(item, actions: actions)
        return item
    }
}
