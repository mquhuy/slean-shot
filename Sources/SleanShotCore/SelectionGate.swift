public struct SelectionGate: Sendable {
    private var active = false

    public init() {}

    public mutating func begin() -> Bool {
        guard !active else { return false }
        active = true
        return true
    }

    public mutating func end() {
        active = false
    }
}
