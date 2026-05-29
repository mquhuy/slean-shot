import Foundation

public struct CapturePoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct CaptureRect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    var maxX: Double { x + width }
    var maxY: Double { y + height }
}

public struct CaptureDisplay: Equatable, Sendable {
    public let id: UInt32
    public let frame: CaptureRect
    public let scaleFactor: Double

    public init(id: UInt32, frame: CaptureRect, scaleFactor: Double) {
        self.id = id
        self.frame = frame
        self.scaleFactor = scaleFactor
    }
}

public struct CaptureArea: Equatable, Sendable {
    public static let minimumSize: Double = 8

    public let display: CaptureDisplay
    public let rect: CaptureRect

    public init(display: CaptureDisplay, rect: CaptureRect) {
        self.display = display
        self.rect = rect
    }

    public static func fromDrag(display: CaptureDisplay, start: CapturePoint, end: CapturePoint) -> CaptureArea? {
        let rawMinX = min(start.x, end.x)
        let rawMinY = min(start.y, end.y)
        let rawMaxX = max(start.x, end.x)
        let rawMaxY = max(start.y, end.y)

        let minX = max(display.frame.x, rawMinX)
        let minY = max(display.frame.y, rawMinY)
        let maxX = min(display.frame.maxX, rawMaxX)
        let maxY = min(display.frame.maxY, rawMaxY)
        let width = max(0, maxX - minX)
        let height = max(0, maxY - minY)

        guard width >= minimumSize, height >= minimumSize else { return nil }

        return CaptureArea(
            display: display,
            rect: CaptureRect(x: minX, y: minY, width: width, height: height)
        )
    }
}
