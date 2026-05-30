import Foundation

public protocol AnnotationEditing: Sendable {
    @MainActor func editImage(data: Data)
}

public struct NoAnnotationEditor: AnnotationEditing {
    public init() {}

    @MainActor public func editImage(data: Data) {}
}
