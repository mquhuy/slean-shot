public enum SleanShotCommand: CaseIterable, Equatable, Sendable {
    case screenshotArea
    case screenshotFullScreen
    case recordArea
    case recordFullScreen

    public static let menuCommands: [SleanShotCommand] = [
        .screenshotArea,
        .screenshotFullScreen,
        .recordArea,
        .recordFullScreen
    ]

    public var title: String {
        switch self {
        case .screenshotArea:
            "Screenshot Area"
        case .screenshotFullScreen:
            "Screenshot Full Screen"
        case .recordArea:
            "Record Area"
        case .recordFullScreen:
            "Record Full Screen"
        }
    }

    public var unavailableMessage: String {
        switch self {
        case .screenshotArea:
            "Area screenshots are available."
        case .screenshotFullScreen:
            "Full-screen screenshots are not implemented yet."
        case .recordArea:
            "Area recording is not implemented yet."
        case .recordFullScreen:
            "Full-screen recording is not implemented yet."
        }
    }
}
