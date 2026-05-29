import SwiftUI

struct AnnotationCanvasView: View {
    @Binding var lines: [Line]

    var body: some View {
        Canvas { context, size in
            for line in lines where line.points.count > 1 {
                var path = Path()
                path.move(to: line.points[0])
                for point in line.points.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(line.color), lineWidth: line.width)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if lines.isEmpty {
                        lines = [Line(points: [value.location])]
                    } else if lines.last!.points.isEmpty {
                        lines[lines.count - 1] = Line(points: [value.location])
                    } else {
                        lines[lines.count - 1].points.append(value.location)
                    }
                }
                .onEnded { _ in
                    lines.append(Line(points: []))
                }
        )
    }
}

struct Line: Equatable, Sendable {
    var points: [CGPoint]
    var color: Color
    var width: CGFloat

    init(points: [CGPoint] = [], color: Color = .black, width: CGFloat = 3) {
        self.points = points
        self.color = color
        self.width = width
    }
}
