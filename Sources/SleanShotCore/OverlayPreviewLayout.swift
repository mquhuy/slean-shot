import Foundation

public struct OverlayPreviewLayout: Equatable, Sendable {
    public let previewWidth: Double
    public let previewHeight: Double
    public let windowWidth: Double
    public let windowHeight: Double

    public init(screenWidth: Double, screenHeight: Double, proportion: Double = 0.12, padding: Double = 40) {
        previewWidth = screenWidth * proportion
        previewHeight = screenHeight * proportion
        windowWidth = previewWidth + padding
        windowHeight = previewHeight + padding
    }
}
