import Foundation
import OSLog

private let coordinatorLogger = Logger(subsystem: "com.huy.SleanShot", category: "AppCoordinator")

public protocol ClipboardService: Sendable {
    func copyImageData(_ data: Data)
    func copyFileURL(_ url: URL)
}

public extension ClipboardService {
    // Default no-op so screenshot-only mocks need not implement recording copy.
    func copyFileURL(_ url: URL) {}
}

public protocol OverlayManaging: Sendable {
    @MainActor func pin(_ item: CaptureItem, actions: OverlayActions)
    @MainActor func remove(_ id: UUID)
}

public actor AppCoordinator {
    private let settings: SettingsProviding
    private let clipboard: ClipboardService
    private let overlays: OverlayManaging
    private let fileExport: FileExportService
    private let permissionManager: PermissionManaging
    private let captureEngine: CaptureEngine
    private let areaSelection: AreaSelectionService
    private let annotationEditor: AnnotationEditing
    private let recordingEngine: RecordingEngine

    private var activeRecording: RecordingHandle?

    public init(
        settings: SettingsProviding,
        clipboard: ClipboardService,
        overlays: OverlayManaging,
        fileExport: FileExportService,
        permissionManager: PermissionManaging,
        captureEngine: CaptureEngine,
        areaSelection: AreaSelectionService = NoAreaSelectionService(),
        annotationEditor: AnnotationEditing = NoAnnotationEditor(),
        recordingEngine: RecordingEngine = NoRecordingEngine()
    ) {
        self.settings = settings
        self.clipboard = clipboard
        self.overlays = overlays
        self.fileExport = fileExport
        self.permissionManager = permissionManager
        self.captureEngine = captureEngine
        self.areaSelection = areaSelection
        self.annotationEditor = annotationEditor
        self.recordingEngine = recordingEngine
    }

    public var isRecording: Bool {
        activeRecording != nil
    }

    public func handle(_ command: SleanShotCommand) async throws {
        switch command {
        case .screenshotFullScreen:
            try await ensurePermission()
            let data = try await captureEngine.captureFullScreen()
            await receiveScreenshot(data)

        case .screenshotArea:
            coordinatorLogger.info("coordinator screenshotArea permission=\(self.permissionManager.hasScreenCaptureAccess)")
            try await ensurePermission()
            coordinatorLogger.info("coordinator selecting area")
            guard let area = await areaSelection.selectArea() else { return }
            coordinatorLogger.info("coordinator selected area rect=\(area.rect.width)x\(area.rect.height)")
            let data = try await captureEngine.captureArea(area)
            await receiveScreenshot(data)

        case .recordFullScreen:
            try await ensurePermission()
            try await startRecording(.fullScreen)

        case .recordArea:
            try await ensurePermission()
            guard let area = await areaSelection.selectArea() else { return }
            try await startRecording(.area(area))
        }
    }

    private func ensurePermission() async throws {
        guard permissionManager.hasScreenCaptureAccess else {
            _ = await permissionManager.requestScreenCaptureAccess()
            throw CaptureError.permissionDenied
        }
    }

    // MARK: Recording

    public func startRecording(_ target: RecordingTarget) async throws {
        guard activeRecording == nil else {
            coordinatorLogger.info("startRecording ignored; already recording")
            return
        }
        let handle = try await recordingEngine.startRecording(target)
        activeRecording = handle
        coordinatorLogger.info("recording started")
    }

    public func stopRecording() async throws {
        guard let handle = activeRecording else { return }
        activeRecording = nil
        let result = try await handle.stop()
        coordinatorLogger.info("recording stopped url=\(result.fileURL.lastPathComponent)")
        await receiveRecording(fileURL: result.fileURL, thumbnailData: result.thumbnailData)
    }

    // MARK: Receiving captures

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
            },
            edit: { [annotationEditor, imageData] in
                annotationEditor.editImage(data: imageData)
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
            copy: { [clipboard, fileURL] in
                clipboard.copyFileURL(fileURL)
            },
            save: { [fileExport, fileURL] in
                fileExport.saveFile(fileURL, suggestedName: fileURL.lastPathComponent)
            },
            drop: { [overlays, fileExport, id = item.id, fileURL] in
                overlays.remove(id)
                fileExport.deleteTemporaryFile(fileURL)
            },
            edit: {}
        )

        await overlays.pin(item, actions: actions)
        return item
    }
}
