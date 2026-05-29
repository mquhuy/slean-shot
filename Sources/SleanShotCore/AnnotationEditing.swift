import Foundation

public protocol AnnotationEditing: Sendable {
    @MainActor func editImage(data: Data)
}
