import CoreGraphics
import Foundation
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
}
