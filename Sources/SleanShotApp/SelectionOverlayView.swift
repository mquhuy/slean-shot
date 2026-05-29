import SwiftUI
import SleanShotCore

struct SelectionOverlayView: View {
    let display: CaptureDisplay
    let onFinish: (CaptureArea?) -> Void

    @State private var start: CGPoint?
    @State private var current: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()

                if let rect = selectionRect {
                    Rectangle()
                        .fill(Color.clear)
                        .background(.clear)
                        .border(Color.white, width: 1)
                        .overlay(Rectangle().stroke(Color.blue, lineWidth: 2))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }

                VStack {
                    Text("Drag to capture. Press Esc to cancel.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.top, 28)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if start == nil {
                            start = value.startLocation
                        }
                        current = value.location
                    }
                    .onEnded { value in
                        let area = areaFromDrag(start: value.startLocation, end: value.location, viewHeight: proxy.size.height)
                        onFinish(area)
                    }
            )
        }
    }

    private var selectionRect: CGRect? {
        guard let start, let current else { return nil }
        let minX = min(start.x, current.x)
        let minY = min(start.y, current.y)
        return CGRect(x: minX, y: minY, width: abs(current.x - start.x), height: abs(current.y - start.y))
    }

    private func areaFromDrag(start: CGPoint, end: CGPoint, viewHeight: CGFloat) -> CaptureArea? {
        let appKitStart = CapturePoint(x: display.frame.x + start.x, y: display.frame.y + (viewHeight - start.y))
        let appKitEnd = CapturePoint(x: display.frame.x + end.x, y: display.frame.y + (viewHeight - end.y))
        return CaptureArea.fromDrag(display: display, start: appKitStart, end: appKitEnd)
    }
}
