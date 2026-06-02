import SwiftUI

enum AnnotationTool: String, CaseIterable, Sendable {
    case brush
    case line
    case arrow
    case circle
    case rectangle
    case text

    var icon: String {
        switch self {
        case .brush: return "scribble"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .circle: return "circle"
        case .rectangle: return "rectangle"
        case .text: return "textformat"
        }
    }

    var label: String {
        switch self {
        case .brush: return "Brush"
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .circle: return "Circle"
        case .rectangle: return "Rectangle"
        case .text: return "Text"
        }
    }
}

struct Stroke: Identifiable, Equatable, Sendable {
    let id = UUID()
    var tool: AnnotationTool
    var points: [CGPoint]   // brush = all drag pts; line/arrow = [start, end]
    var color: Color
    var width: CGFloat

    init(tool: AnnotationTool, points: [CGPoint] = [], color: Color = .red, width: CGFloat = 3) {
        self.tool = tool
        self.points = points
        self.color = color
        self.width = width
    }
}

struct TextItem: Identifiable, Equatable, Sendable {
    let id = UUID()
    var text: String
    var position: CGPoint   // display coords, top-leading
    var color: Color
    var fontSize: CGFloat
}

struct AnnotationCanvasView: View {
    @Binding var strokes: [Stroke]
    let selectedTool: AnnotationTool
    let selectedColor: Color
    let selectedWidth: CGFloat
    let onPlaceText: (CGPoint) -> Void

    var body: some View {
        Canvas { context, _ in
            for stroke in strokes {
                draw(stroke, in: context)
            }
        }
        .gesture(drawGesture)
    }

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard selectedTool != .text else { return }
                let pt = value.location
                if strokes.isEmpty || !(strokes.last!.points.isEmpty) && strokes.last!.tool != selectedTool {
                    strokes.append(Stroke(tool: selectedTool, points: [pt], color: selectedColor, width: selectedWidth))
                    return
                }
                if strokes.last!.points.isEmpty {
                    strokes[strokes.count - 1] = Stroke(tool: selectedTool, points: [pt], color: selectedColor, width: selectedWidth)
                    return
                }
                switch selectedTool {
                case .brush:
                    strokes[strokes.count - 1].points.append(pt)
                case .line, .arrow, .circle, .rectangle:
                    if strokes[strokes.count - 1].points.count == 1 {
                        strokes[strokes.count - 1].points.append(pt)
                    } else {
                        strokes[strokes.count - 1].points[1] = pt
                    }
                case .text:
                    break
                }
            }
            .onEnded { value in
                if selectedTool == .text {
                    onPlaceText(value.location)
                    return
                }
                if let last = strokes.last, last.points.count < 2 {
                    strokes.removeLast()
                }
                strokes.append(Stroke(tool: selectedTool, points: [], color: selectedColor, width: selectedWidth))
            }
    }

    private func draw(_ stroke: Stroke, in context: GraphicsContext) {
        guard stroke.points.count >= 2 else { return }
        let style = StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round)
        switch stroke.tool {
        case .brush:
            var path = Path()
            path.move(to: stroke.points[0])
            for pt in stroke.points.dropFirst() { path.addLine(to: pt) }
            context.stroke(path, with: .color(stroke.color), style: style)

        case .line:
            var path = Path()
            path.move(to: stroke.points[0])
            path.addLine(to: stroke.points[1])
            context.stroke(path, with: .color(stroke.color), style: style)

        case .arrow:
            let start = stroke.points[0]
            let end = stroke.points[1]
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            let angle = atan2(end.y - start.y, end.x - start.x)
            let headLen = max(stroke.width * 4, 12)
            let headAngle: CGFloat = .pi / 6
            let p1 = CGPoint(x: end.x - headLen * cos(angle - headAngle),
                             y: end.y - headLen * sin(angle - headAngle))
            let p2 = CGPoint(x: end.x - headLen * cos(angle + headAngle),
                             y: end.y - headLen * sin(angle + headAngle))
            path.move(to: end); path.addLine(to: p1)
            path.move(to: end); path.addLine(to: p2)
            context.stroke(path, with: .color(stroke.color), style: style)

        case .circle:
            let rect = CGRect(x: min(stroke.points[0].x, stroke.points[1].x),
                              y: min(stroke.points[0].y, stroke.points[1].y),
                              width: abs(stroke.points[1].x - stroke.points[0].x),
                              height: abs(stroke.points[1].y - stroke.points[0].y))
            context.stroke(Path(ellipseIn: rect), with: .color(stroke.color), style: style)

        case .rectangle:
            let rect = CGRect(x: min(stroke.points[0].x, stroke.points[1].x),
                              y: min(stroke.points[0].y, stroke.points[1].y),
                              width: abs(stroke.points[1].x - stroke.points[0].x),
                              height: abs(stroke.points[1].y - stroke.points[0].y))
            context.stroke(Path(rect), with: .color(stroke.color), style: style)

        case .text:
            break
        }
    }
}
