import CoreGraphics
import Foundation
import ScreenCaptureKit
import SleanShotCore

public struct AppPermissionManager: PermissionManaging {
    public init() {}

    public var hasScreenCaptureAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }

    public func requestScreenCaptureAccess() async -> Bool {
        // CGRequestScreenCaptureAccess is synchronous and blocks until user responds
        // or returns immediately if already granted/denied.
        return CGRequestScreenCaptureAccess()
    }

    /// Verifies SCShareableContent is actually reachable. Returns the underlying
    /// error when the TCC entry is stale (CGPreflight says granted but SCKit
    /// rejects), nil when capture is healthy.
    public func validateScreenCaptureAccess() async -> Error? {
        do {
            if #available(macOS 14.4, *) {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            } else {
                _ = try await SCShareableContent.current
            }
            return nil
        } catch {
            return error
        }
    }
}
