import Foundation
import SleanShotCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fatalError(message)
    }
}

func testScreenshotCaptureItemsUseInMemoryImages() {
    let pngData = Data([0x89, 0x50, 0x4E, 0x47])
    let item = CaptureItem.screenshot(id: UUID(), imageData: pngData)

    expect(item.kind == .screenshot, "Screenshot item should have screenshot kind")
    expect(item.imageData == pngData, "Screenshot item should keep image data")
    expect(item.fileURL == nil, "Screenshot item should not require a file URL")
}

func testRecordingCaptureItemsUseFileURLsAndThumbnails() {
    let recordingURL = URL(fileURLWithPath: "/tmp/recording.mov")
    let thumbnail = Data([0x01, 0x02])

    let item = CaptureItem.recording(id: UUID(), fileURL: recordingURL, thumbnailData: thumbnail)

    expect(item.kind == .recording, "Recording item should have recording kind")
    expect(item.fileURL == recordingURL, "Recording item should keep file URL")
    expect(item.thumbnailData == thumbnail, "Recording item should keep thumbnail data")
    expect(item.imageData == nil, "Recording item should not keep full image data")
}

func testSettingsDefaultToAutoCopyScreenshotsEnabled() {
    let settings = SettingsStore()

    expect(settings.autoCopyScreenshotToClipboard, "Settings should auto-copy screenshots by default")
}

func testMenuCommandsExposeExpectedTitles() {
    let titles = SleanShotCommand.menuCommands.map(\.title)

    expect(
        titles == [
            "Screenshot Area",
            "Screenshot Full Screen",
            "Record Area",
            "Record Full Screen"
        ],
        "Menu commands should expose capture and recording actions in MVP order"
    )
}

func testCaptureCommandsAreUnavailableUntilEnginesExist() {
    let unavailableMessages = SleanShotCommand.menuCommands.map(\.unavailableMessage)

    expect(
        unavailableMessages == [
            "Area screenshots are not implemented yet.",
            "Full-screen screenshots are not implemented yet.",
            "Area recording is not implemented yet.",
            "Full-screen recording is not implemented yet."
        ],
        "Menu commands should be honest placeholders until capture engines exist"
    )
}

func testXcodeAppProjectDeclaresBundleIdentifier() {
    let projectPath = "SleanShot.xcodeproj/project.pbxproj"
    guard FileManager.default.fileExists(atPath: projectPath) else {
        fatalError("SleanShot.xcodeproj should exist for Xcode to run a bundled macOS app")
    }

    guard let project = try? String(contentsOfFile: projectPath, encoding: .utf8) else {
        fatalError("SleanShot.xcodeproj/project.pbxproj should be readable")
    }

    expect(
        project.contains("PRODUCT_BUNDLE_IDENTIFIER = com.huy.SleanShot;"),
        "Xcode app target should declare a main bundle identifier"
    )
}

func testPackageDoesNotExposeNonBundledAppExecutable() {
    guard let manifest = try? String(contentsOfFile: "Package.swift", encoding: .utf8) else {
        fatalError("Package.swift should be readable")
    }

    expect(
        !manifest.contains("name: \"SleanShotApp\""),
        "SwiftPM should not expose a non-bundled SleanShotApp executable that Xcode can run by mistake"
    )
}

struct MockPermissionManager: PermissionManaging {
    var hasScreenCaptureAccess: Bool = true
    func requestScreenCaptureAccess() async -> Bool { return true }
}

struct MockCaptureEngine: CaptureEngine {
    func captureFullScreen() async throws -> Data {
        return Data("mock_image".utf8)
    }
}

@MainActor
final class MockOverlayManager: OverlayManaging {
    var pinnedItems: [CaptureItem] = []
    var actionsByID: [UUID: OverlayActions] = [:]
    var removedIDs: [UUID] = []

    func pin(_ item: CaptureItem, actions: OverlayActions) {
        pinnedItems.append(item)
        actionsByID[item.id] = actions
    }

    func remove(_ id: UUID) {
        removedIDs.append(id)
    }
}

final class MockFileExportService: @unchecked Sendable, FileExportService {
    private var _savedData: Data?
    private let lock = NSLock()

    var savedData: Data? {
        lock.lock()
        defer { lock.unlock() }
        return _savedData
    }

    @MainActor
    func saveImageData(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        _savedData = data
    }
}

final class MockClipboardService: @unchecked Sendable, ClipboardService {
    private let lock = NSLock()
    private var _copiedData: Data?
    
    var copiedData: Data? {
        lock.lock()
        defer { lock.unlock() }
        return _copiedData
    }
    
    func copyImageData(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        _copiedData = data
    }
}

@MainActor
func testOverlayActionsCopySaveDrop() async {
    let clipboard = MockClipboardService()
    let exporter = MockFileExportService()
    let overlays = MockOverlayManager()
    let permissions = MockPermissionManager()
    let capture = MockCaptureEngine()

    let coordinator = AppCoordinator(
        settings: SettingsStore(autoCopyScreenshotToClipboard: false),
        clipboard: clipboard,
        overlays: overlays,
        fileExport: exporter,
        permissionManager: permissions,
        captureEngine: capture
    )

    let imageData = Data([0xDE, 0xAD, 0xBE, 0xEF])
    let item = await coordinator.receiveScreenshot(imageData)

    guard let actions = overlays.actionsByID[item.id] else {
        fatalError("Overlay actions should be created")
    }

    actions.copy()
    actions.save()
    actions.drop()

    expect(clipboard.copiedData == imageData, "Copy should write image data to clipboard")
    expect(exporter.savedData == imageData, "Save should pass image data to export service")
    expect(overlays.removedIDs == [item.id], "Drop should remove the overlay")
}

@MainActor
func testCoordinatorPinsAndCopiesScreenshotWhenAutoCopyEnabled() async {
    let clipboard = MockClipboardService()
    let overlays = MockOverlayManager()
    let permissions = MockPermissionManager()
    let capture = MockCaptureEngine()
    let coordinator = AppCoordinator(
        settings: SettingsStore(autoCopyScreenshotToClipboard: true),
        clipboard: clipboard,
        overlays: overlays,
        fileExport: MockFileExportService(),
        permissionManager: permissions,
        captureEngine: capture
    )
    let imageData = Data([0x0A, 0x0B])

    let item = await coordinator.receiveScreenshot(imageData)
    
    expect(item.kind == .screenshot, "Coordinator should create a screenshot item")
    let pinned = overlays.pinnedItems
    expect(pinned == [item], "Coordinator should pin screenshot overlays")
    let copied = clipboard.copiedData
    expect(copied == imageData, "Coordinator should auto-copy screenshot image data")
}

@MainActor
func testCoordinatorDoesNotCopyScreenshotWhenAutoCopyDisabled() async {
    let clipboard = MockClipboardService()
    let overlays = MockOverlayManager()
    let permissions = MockPermissionManager()
    let capture = MockCaptureEngine()
    let coordinator = AppCoordinator(
        settings: SettingsStore(autoCopyScreenshotToClipboard: false),
        clipboard: clipboard,
        overlays: overlays,
        fileExport: MockFileExportService(),
        permissionManager: permissions,
        captureEngine: capture
    )

    _ = await coordinator.receiveScreenshot(Data([0x0A, 0x0B]))
    
    let copied = clipboard.copiedData
    expect(copied == nil, "Coordinator should not copy screenshots when auto-copy is disabled")
}

@MainActor
func testCoordinatorPinsRecordingWithoutCopyingImageData() async {
    let clipboard = MockClipboardService()
    let overlays = MockOverlayManager()
    let permissions = MockPermissionManager()
    let capture = MockCaptureEngine()
    let coordinator = AppCoordinator(
        settings: SettingsStore(autoCopyScreenshotToClipboard: true),
        clipboard: clipboard,
        overlays: overlays,
        fileExport: MockFileExportService(),
        permissionManager: permissions,
        captureEngine: capture
    )
    let recordingURL = URL(fileURLWithPath: "/tmp/recording.mov")
    let thumbnail = Data([0x03, 0x04])

    let item = await coordinator.receiveRecording(fileURL: recordingURL, thumbnailData: thumbnail)
    
    expect(item.kind == .recording, "Coordinator should create a recording item")
    expect(item.fileURL == recordingURL, "Recording item should keep its file URL")
    expect(item.thumbnailData == thumbnail, "Recording item should keep thumbnail data")
    let pinned = overlays.pinnedItems
    expect(pinned == [item], "Coordinator should pin recording overlays")
    let copied = clipboard.copiedData
    expect(copied == nil, "Coordinator should not copy recordings as image data")
}

@MainActor
func testCoordinatorFullScreenCapture() async {
    let settings = SettingsStore()
    let clipboard = MockClipboardService()
    let overlays = MockOverlayManager()
    let permissions = MockPermissionManager()
    let capture = MockCaptureEngine()
    
    let coordinator = AppCoordinator(
        settings: settings,
        clipboard: clipboard,
        overlays: overlays,
        fileExport: MockFileExportService(),
        permissionManager: permissions,
        captureEngine: capture
    )
    
    try? await coordinator.handle(.screenshotFullScreen)
    
    let pinned = overlays.pinnedItems
    expect(pinned.count == 1, "Should have pinned one item")
    expect(pinned.first?.kind == .screenshot, "Item should be a screenshot")
    expect(pinned.first?.imageData == Data("mock_image".utf8), "Item should have correct data")
    print("testCoordinatorFullScreenCapture passed")
}

@MainActor
func runTests() async {
    testScreenshotCaptureItemsUseInMemoryImages()
    testRecordingCaptureItemsUseFileURLsAndThumbnails()
    testSettingsDefaultToAutoCopyScreenshotsEnabled()
    testMenuCommandsExposeExpectedTitles()
    testCaptureCommandsAreUnavailableUntilEnginesExist()
    testXcodeAppProjectDeclaresBundleIdentifier()
    testPackageDoesNotExposeNonBundledAppExecutable()
    await testCoordinatorPinsAndCopiesScreenshotWhenAutoCopyEnabled()
    await testCoordinatorDoesNotCopyScreenshotWhenAutoCopyDisabled()
    await testCoordinatorPinsRecordingWithoutCopyingImageData()
    await testOverlayActionsCopySaveDrop()
    await testCoordinatorFullScreenCapture()
    
    print("SleanShotCoreTestRunner passed")
}

await runTests()
