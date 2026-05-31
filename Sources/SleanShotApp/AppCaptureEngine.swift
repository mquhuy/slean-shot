// Sources/SleanShotApp/AppCaptureEngine.swift
import AppKit
import Foundation
import ScreenCaptureKit
import SleanShotCore

/// UserDefaults key controlling whether SleanShot's own windows are excluded
/// from captures/recordings. Absent key defaults to enabled (true).
let excludeSleanShotFromCapturesKey = "excludeSleanShotFromCaptures"

extension UserDefaults {
    var excludeSleanShotFromCaptures: Bool {
        object(forKey: excludeSleanShotFromCapturesKey) == nil
            ? true
            : bool(forKey: excludeSleanShotFromCapturesKey)
    }
}

extension SCShareableContent {
    /// All on-screen windows owned by SleanShot itself (pinned overlays, the
    /// selection overlay, the annotation editor, the recording control panel).
    /// These must be excluded from every capture/recording so SleanShot's own UI
    /// never appears in the user's screenshots or videos.
    ///
    /// Returns an empty list when the user disables exclusion in Settings, so
    /// SleanShot's own UI is allowed to appear in captures.
    func sleanShotWindows() -> [SCWindow] {
        guard UserDefaults.standard.excludeSleanShotFromCaptures else { return [] }
        let bundleID = Bundle.main.bundleIdentifier
        let pid = ProcessInfo.processInfo.processIdentifier
        return windows.filter { window in
            if let owningBundle = window.owningApplication?.bundleIdentifier,
               let bundleID, owningBundle == bundleID {
                return true
            }
            return window.owningApplication?.processID == pid
        }
    }
}

public struct AppCaptureEngine: CaptureEngine {
    public init() {}

    public func captureFullScreen() async throws -> Data {
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
        
        guard let display = content.displays.first else {
            throw CaptureError.captureFailed("No displays found")
        }
        
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.showsCursor = false
        
        let filter = SCContentFilter(display: display, excludingWindows: content.sleanShotWindows())
        
        do {
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            
            let bitmapImage = NSBitmapImageRep(cgImage: cgImage)
            guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                throw CaptureError.captureFailed("Could not generate PNG data")
            }
            
            return pngData
        } catch {
            throw CaptureError.captureFailed(error.localizedDescription)
        }
    }

    public func captureArea(_ area: CaptureArea) async throws -> Data {
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

        guard let display = content.displays.first(where: { $0.displayID == area.display.id }) ?? content.displays.first else {
            throw CaptureError.captureFailed("No displays found")
        }

        let scale = area.display.scaleFactor
        // Convert from AppKit screen coords (bottom-left origin) to display pixel coords (top-left origin)
        let sourceX = (area.rect.x - area.display.frame.x) * scale
        let displayPixelHeight = area.display.frame.height * scale
        let selectionTop = (area.rect.y + area.rect.height - area.display.frame.y) * scale
        let sourceY = displayPixelHeight - selectionTop
        let sourceRect = CGRect(
            x: sourceX,
            y: sourceY,
            width: area.rect.width * scale,
            height: area.rect.height * scale
        )

        let config = SCStreamConfiguration()
        config.width = Int(area.rect.width * scale)
        config.height = Int(area.rect.height * scale)
        config.sourceRect = sourceRect
        config.showsCursor = false

        let filter = SCContentFilter(display: display, excludingWindows: content.sleanShotWindows())

        do {
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            let bitmapImage = NSBitmapImageRep(cgImage: cgImage)
            guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                throw CaptureError.captureFailed("Could not generate PNG data")
            }
            return pngData
        } catch {
            throw CaptureError.captureFailed(error.localizedDescription)
        }
    }
}
