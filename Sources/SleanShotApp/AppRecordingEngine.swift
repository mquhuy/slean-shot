import AppKit
import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import OSLog
import ScreenCaptureKit
import SleanShotCore

private let recordingLogger = Logger(subsystem: "com.huy.SleanShot", category: "RecordingEngine")

/// Records the screen with ScreenCaptureKit, streaming H.264 frames straight to
/// a `.mov` on disk via `AVAssetWriter`. No raw video buffers are retained after
/// each frame is appended (per the memory constraint in CLAUDE.md).
public struct AppRecordingEngine: RecordingEngine {
    public init() {}

    public func startRecording(_ target: RecordingTarget) async throws -> RecordingHandle {
        let content: SCShareableContent
        do {
            if #available(macOS 14.4, *) {
                content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            } else {
                content = try await SCShareableContent.current
            }
        } catch {
            throw CaptureError.captureFailed("Could not get shareable content")
        }

        // Resolve the target display + cropped source rect (if area).
        let display: SCDisplay
        let outputWidth: Int
        let outputHeight: Int
        var sourceRect: CGRect?

        switch target {
        case .fullScreen:
            guard let first = content.displays.first else {
                throw CaptureError.captureFailed("No displays found")
            }
            display = first
            outputWidth = first.width
            outputHeight = first.height

        case .area(let area):
            guard let matched = content.displays.first(where: { $0.displayID == area.display.id }) ?? content.displays.first else {
                throw CaptureError.captureFailed("No displays found")
            }
            display = matched
            let scale = area.display.scaleFactor
            // Mirror the screenshot path: AppKit (bottom-left) -> display pixels (top-left).
            let sourceX = (area.rect.x - area.display.frame.x) * scale
            let displayPixelHeight = area.display.frame.height * scale
            let selectionTop = (area.rect.y + area.rect.height - area.display.frame.y) * scale
            let sourceY = displayPixelHeight - selectionTop
            outputWidth = Int(area.rect.width * scale)
            outputHeight = Int(area.rect.height * scale)
            sourceRect = CGRect(x: sourceX, y: sourceY, width: area.rect.width * scale, height: area.rect.height * scale)
        }

        guard outputWidth > 0, outputHeight > 0 else {
            throw CaptureError.captureFailed("Recording area is too small")
        }

        let config = SCStreamConfiguration()
        config.width = outputWidth
        config.height = outputHeight
        if let sourceRect { config.sourceRect = sourceRect }
        config.showsCursor = true
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.queueDepth = 6

        let filter = SCContentFilter(display: display, excludingWindows: content.sleanShotWindows())

        let fileURL = Self.makeTemporaryURL()
        let session = try RecordingSession(
            fileURL: fileURL,
            width: outputWidth,
            height: outputHeight,
            filter: filter,
            configuration: config
        )
        try await session.begin()
        recordingLogger.info("recording begin url=\(fileURL.lastPathComponent) size=\(outputWidth)x\(outputHeight)")
        return session
    }

    private static func makeTemporaryURL() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SleanShot", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return dir.appendingPathComponent("Recording-\(stamp).mov")
    }
}

/// Owns the live `SCStream` + `AVAssetWriter`. Frame callbacks arrive on a
/// background queue, so all mutable state is guarded by a lock.
final class RecordingSession: NSObject, RecordingHandle, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let stream: SCStream
    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let fileURL: URL
    private let sampleQueue = DispatchQueue(label: "com.huy.SleanShot.recording.samples")

    private let lock = NSLock()
    private var sessionStarted = false
    private var finished = false

    init(fileURL: URL, width: Int, height: Int, filter: SCContentFilter, configuration: SCStreamConfiguration) throws {
        self.fileURL = fileURL
        self.writer = try AVAssetWriter(outputURL: fileURL, fileType: .mov)

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        self.videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        self.videoInput.expectsMediaDataInRealTime = true

        self.stream = SCStream(filter: filter, configuration: configuration, delegate: nil)

        super.init()

        guard writer.canAdd(videoInput) else {
            throw CaptureError.captureFailed("Could not configure video writer")
        }
        writer.add(videoInput)

        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
    }

    func begin() async throws {
        guard writer.startWriting() else {
            throw CaptureError.captureFailed(writer.error?.localizedDescription ?? "Could not start writer")
        }
        try await stream.startCapture()
    }

    // MARK: SCStreamOutput

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, CMSampleBufferDataIsReady(sampleBuffer) else { return }

        // Only append frames SCK marked as complete.
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
           let statusRaw = attachments.first?[.status] as? Int,
           let status = SCFrameStatus(rawValue: statusRaw),
           status != .complete {
            return
        }

        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }

        if !sessionStarted {
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startSession(atSourceTime: pts)
            sessionStarted = true
        }

        if videoInput.isReadyForMoreMediaData {
            videoInput.append(sampleBuffer)
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        recordingLogger.error("stream stopped with error: \(error.localizedDescription)")
    }

    // MARK: RecordingHandle

    func stop() async throws -> RecordingResult {
        try? await stream.stopCapture()

        lock.lock()
        let didStart = sessionStarted
        finished = true
        videoInput.markAsFinished()
        lock.unlock()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting {
                continuation.resume()
            }
        }

        if !didStart || writer.status != .completed {
            recordingLogger.error("writer status=\(self.writer.status.rawValue) error=\(self.writer.error?.localizedDescription ?? "none")")
        }

        let thumbnail = Self.thumbnail(for: fileURL)
        return RecordingResult(fileURL: fileURL, thumbnailData: thumbnail)
    }

    private static func thumbnail(for url: URL) -> Data? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        guard let cgImage = try? generator.copyCGImage(at: CMTime(value: 0, timescale: 60), actualTime: nil) else {
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }
}
