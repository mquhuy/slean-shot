import Foundation

public struct OverlayActions: Sendable {
    public let copy: @MainActor @Sendable () -> Void
    public let save: @MainActor @Sendable () -> Void
    public let drop: @MainActor @Sendable () -> Void

    public init(
        copy: @escaping @MainActor @Sendable () -> Void,
        save: @escaping @MainActor @Sendable () -> Void,
        drop: @escaping @MainActor @Sendable () -> Void
    ) {
        self.copy = copy
        self.save = save
        self.drop = drop
    }
}
