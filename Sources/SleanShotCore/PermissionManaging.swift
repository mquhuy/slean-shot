import Foundation

public protocol PermissionManaging: Sendable {
    var hasScreenCaptureAccess: Bool { get }
    func requestScreenCaptureAccess() async -> Bool
}
