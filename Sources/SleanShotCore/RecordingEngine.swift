import Foundation

public enum RecordingTarget: Equatable, Sendable {
    case fullScreen
    case area(CaptureArea)
}

public struct RecordingResult: Equatable, Sendable {
    public let fileURL: URL
    public let thumbnailData: Data?

    public init(fileURL: URL, thumbnailData: Data?) {
        self.fileURL = fileURL
        self.thumbnailData = thumbnailData
    }
}

/// Starts a recording and hands back a handle the coordinator stops later.
/// Implementations must stream frames to disk and must not retain raw buffers.
public protocol RecordingEngine: Sendable {
    func startRecording(_ target: RecordingTarget) async throws -> RecordingHandle
}

public protocol RecordingHandle: Sendable {
    func stop() async throws -> RecordingResult
}

/// Default engine used in tests / when recording is unavailable.
public struct NoRecordingEngine: RecordingEngine {
    public init() {}

    public func startRecording(_ target: RecordingTarget) async throws -> RecordingHandle {
        throw CaptureError.captureFailed("Recording is not available.")
    }
}
