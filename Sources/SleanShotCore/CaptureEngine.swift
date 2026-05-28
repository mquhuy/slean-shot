import Foundation

public protocol CaptureEngine: Sendable {
    func captureFullScreen() async throws -> Data
}

public enum CaptureError: Error, Equatable {
    case permissionDenied
    case permissionNeedsRestart
    case captureFailed(String)
}
