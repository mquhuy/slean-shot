// Sources/SleanShotApp/AppCaptureEngine.swift
import AppKit
import Foundation
import ScreenCaptureKit
import SleanShotCore

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
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
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
