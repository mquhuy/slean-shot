public protocol AreaSelectionService: Sendable {
    func selectArea() async -> CaptureArea?
}

public struct NoAreaSelectionService: AreaSelectionService {
    public init() {}

    public func selectArea() async -> CaptureArea? {
        nil
    }
}
