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

final class ClipboardSpy: ClipboardService {
    var copiedImageData: [Data] = []

    func copyImageData(_ data: Data) {
        copiedImageData.append(data)
    }
}

final class OverlaySpy: OverlayManaging {
    var pinnedItems: [CaptureItem] = []

    func pin(_ item: CaptureItem) {
        pinnedItems.append(item)
    }
}

func testCoordinatorPinsAndCopiesScreenshotWhenAutoCopyEnabled() {
    let clipboard = ClipboardSpy()
    let overlays = OverlaySpy()
    let coordinator = AppCoordinator(
        settings: SettingsStore(autoCopyScreenshotToClipboard: true),
        clipboard: clipboard,
        overlays: overlays
    )
    let imageData = Data([0x0A, 0x0B])

    let item = coordinator.receiveScreenshot(imageData)

    expect(item.kind == .screenshot, "Coordinator should create a screenshot item")
    expect(overlays.pinnedItems == [item], "Coordinator should pin screenshot overlays")
    expect(clipboard.copiedImageData == [imageData], "Coordinator should auto-copy screenshot image data")
}

func testCoordinatorDoesNotCopyScreenshotWhenAutoCopyDisabled() {
    let clipboard = ClipboardSpy()
    let overlays = OverlaySpy()
    let coordinator = AppCoordinator(
        settings: SettingsStore(autoCopyScreenshotToClipboard: false),
        clipboard: clipboard,
        overlays: overlays
    )

    _ = coordinator.receiveScreenshot(Data([0x0A, 0x0B]))

    expect(clipboard.copiedImageData.isEmpty, "Coordinator should not copy screenshots when auto-copy is disabled")
}

func testCoordinatorPinsRecordingWithoutCopyingImageData() {
    let clipboard = ClipboardSpy()
    let overlays = OverlaySpy()
    let coordinator = AppCoordinator(
        settings: SettingsStore(autoCopyScreenshotToClipboard: true),
        clipboard: clipboard,
        overlays: overlays
    )
    let recordingURL = URL(fileURLWithPath: "/tmp/recording.mov")
    let thumbnail = Data([0x03, 0x04])

    let item = coordinator.receiveRecording(fileURL: recordingURL, thumbnailData: thumbnail)

    expect(item.kind == .recording, "Coordinator should create a recording item")
    expect(item.fileURL == recordingURL, "Recording item should keep its file URL")
    expect(item.thumbnailData == thumbnail, "Recording item should keep thumbnail data")
    expect(overlays.pinnedItems == [item], "Coordinator should pin recording overlays")
    expect(clipboard.copiedImageData.isEmpty, "Coordinator should not copy recordings as image data")
}

testScreenshotCaptureItemsUseInMemoryImages()
testRecordingCaptureItemsUseFileURLsAndThumbnails()
testSettingsDefaultToAutoCopyScreenshotsEnabled()
testMenuCommandsExposeExpectedTitles()
testCaptureCommandsAreUnavailableUntilEnginesExist()
testCoordinatorPinsAndCopiesScreenshotWhenAutoCopyEnabled()
testCoordinatorDoesNotCopyScreenshotWhenAutoCopyDisabled()
testCoordinatorPinsRecordingWithoutCopyingImageData()

print("SleanShotCoreTestRunner passed")
