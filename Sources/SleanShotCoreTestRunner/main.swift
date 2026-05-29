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
            "Area screenshots are available.",
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

func testOverlayPreviewLayoutUsesScreenProportionPlusPadding() {
    let layout = OverlayPreviewLayout(screenWidth: 3840, screenHeight: 2160)

    expect(abs(layout.previewWidth - 460.8) < 0.001, "Preview width should be 12% of screen width")
    expect(abs(layout.previewHeight - 259.2) < 0.001, "Preview height should be 12% of screen height")
    expect(abs(layout.windowWidth - 500.8) < 0.001, "Window width should include horizontal padding")
    expect(abs(layout.windowHeight - 299.2) < 0.001, "Window height should include vertical padding")
}

func testCaptureAreaNormalizesDragPoints() {
    let display = CaptureDisplay(id: 7, frame: CaptureRect(x: 0, y: 0, width: 800, height: 600), scaleFactor: 2)

    let area = CaptureArea.fromDrag(
        display: display,
        start: CapturePoint(x: 300, y: 220),
        end: CapturePoint(x: 120, y: 80)
    )

    expect(area?.rect == CaptureRect(x: 120, y: 80, width: 180, height: 140), "Drag points should normalize to a positive rectangle")
    expect(area?.display == display, "Area should keep the selected display")
}

func testCaptureAreaRejectsTinySelections() {
    let display = CaptureDisplay(id: 7, frame: CaptureRect(x: 0, y: 0, width: 800, height: 600), scaleFactor: 2)

    let area = CaptureArea.fromDrag(
        display: display,
        start: CapturePoint(x: 100, y: 100),
        end: CapturePoint(x: 104, y: 106)
    )

    expect(area == nil, "Tiny accidental drags should cancel selection")
}

func testCaptureAreaClampsToDisplayBounds() {
    let display = CaptureDisplay(id: 7, frame: CaptureRect(x: 0, y: 0, width: 800, height: 600), scaleFactor: 2)

    let area = CaptureArea.fromDrag(
        display: display,
        start: CapturePoint(x: 760, y: 560),
        end: CapturePoint(x: 900, y: 700)
    )

    expect(area?.rect == CaptureRect(x: 760, y: 560, width: 40, height: 40), "Selection should clamp to the display frame")
}

struct MockPermissionManager: PermissionManaging {
    var hasScreenCaptureAccess: Bool = true
    func requestScreenCaptureAccess() async -> Bool { return true }
}

struct MockCaptureEngine: CaptureEngine {
    var areaData = Data("mock_area_image".utf8)
    final class State: @unchecked Sendable {
        let lock = NSLock()
        var capturedAreas: [CaptureArea] = []
    }

    let state = State()

    func captureFullScreen() async throws -> Data {
        return Data("mock_image".utf8)
    }

    func captureArea(_ area: CaptureArea) async throws -> Data {
        state.lock.withLock {
            state.capturedAreas.append(area)
        }
        return areaData
    }

    var capturedAreas: [CaptureArea] {
        state.lock.withLock {
            state.capturedAreas
        }
    }
}

struct MockAreaSelectionService: AreaSelectionService {
    let selection: CaptureArea?

    func selectArea() async -> CaptureArea? {
        selection
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
func testRecordingOverlayActionsDropWithoutCopyingOrSaving() async {
    let clipboard = MockClipboardService()
    let exporter = MockFileExportService()
    let overlays = MockOverlayManager()
    let permissions = MockPermissionManager()
    let capture = MockCaptureEngine()
    let coordinator = AppCoordinator(
        settings: SettingsStore(autoCopyScreenshotToClipboard: true),
        clipboard: clipboard,
        overlays: overlays,
        fileExport: exporter,
        permissionManager: permissions,
        captureEngine: capture
    )
    let recordingURL = URL(fileURLWithPath: "/tmp/recording.mov")

    let item = await coordinator.receiveRecording(fileURL: recordingURL, thumbnailData: nil)

    guard let actions = overlays.actionsByID[item.id] else {
        fatalError("Recording overlay actions should be created")
    }

    actions.copy()
    actions.save()
    actions.drop()

    expect(clipboard.copiedData == nil, "Recording copy should not write image data to clipboard")
    expect(exporter.savedData == nil, "Recording save should not export image data")
    expect(overlays.removedIDs == [item.id], "Recording drop should remove the overlay")
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
func testCoordinatorAreaScreenshotCancelDoesNotCaptureOrPin() async {
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
        captureEngine: capture,
        areaSelection: MockAreaSelectionService(selection: nil)
    )

    try? await coordinator.handle(.screenshotArea)

    expect(capture.capturedAreas.isEmpty, "Cancelled area selection should not capture")
    expect(overlays.pinnedItems.isEmpty, "Cancelled area selection should not pin overlays")
    expect(clipboard.copiedData == nil, "Cancelled area selection should not copy image data")
}

@MainActor
func testCoordinatorAreaScreenshotCapturesSelectionAndPinsScreenshot() async {
    let clipboard = MockClipboardService()
    let overlays = MockOverlayManager()
    let permissions = MockPermissionManager()
    let capture = MockCaptureEngine()
    let display = CaptureDisplay(id: 7, frame: CaptureRect(x: 0, y: 0, width: 800, height: 600), scaleFactor: 2)
    let area = CaptureArea(display: display, rect: CaptureRect(x: 20, y: 30, width: 120, height: 90))
    let coordinator = AppCoordinator(
        settings: SettingsStore(autoCopyScreenshotToClipboard: true),
        clipboard: clipboard,
        overlays: overlays,
        fileExport: MockFileExportService(),
        permissionManager: permissions,
        captureEngine: capture,
        areaSelection: MockAreaSelectionService(selection: area)
    )

    try? await coordinator.handle(.screenshotArea)

    expect(capture.capturedAreas == [area], "Area screenshot should capture selected area")
    expect(overlays.pinnedItems.count == 1, "Area screenshot should pin one screenshot")
    expect(overlays.pinnedItems.first?.imageData == Data("mock_area_image".utf8), "Pinned screenshot should use captured area data")
    expect(clipboard.copiedData == Data("mock_area_image".utf8), "Area screenshot should reuse auto-copy flow")
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
    testOverlayPreviewLayoutUsesScreenProportionPlusPadding()
    testCaptureAreaNormalizesDragPoints()
    testCaptureAreaRejectsTinySelections()
    testCaptureAreaClampsToDisplayBounds()
    await testCoordinatorPinsAndCopiesScreenshotWhenAutoCopyEnabled()
    await testCoordinatorDoesNotCopyScreenshotWhenAutoCopyDisabled()
    await testCoordinatorPinsRecordingWithoutCopyingImageData()
    await testRecordingOverlayActionsDropWithoutCopyingOrSaving()
    await testOverlayActionsCopySaveDrop()
    await testCoordinatorFullScreenCapture()
    await testCoordinatorAreaScreenshotCancelDoesNotCaptureOrPin()
    await testCoordinatorAreaScreenshotCapturesSelectionAndPinsScreenshot()
    
    print("SleanShotCoreTestRunner passed")
}

await runTests()
