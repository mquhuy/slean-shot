import PencilKit
import SwiftUI

struct AnnotationCanvasView: NSViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeNSView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.allowsFingerDrawing = false
        return canvas
    }

    func updateNSView(_ nsView: PKCanvasView, context: Context) {
        nsView.drawing = drawing
    }
}
