import AppKit
import OSLog
import PencilKit
import SwiftUI
import SleanShotCore

private let annotationLogger = Logger(subsystem: "com.huy.SleanShot", category: "AnnotationEditor")

@MainActor
final class AppAnnotationEditor: AnnotationEditing {
    private let alertPresenter: AlertPresenting
    private let clipboardService: ClipboardService

    init(alertPresenter: AlertPresenting, clipboardService: ClipboardService) {
        self.alertPresenter = alertPresenter
        self.clipboardService = clipboardService
    }

    func editImage(data: Data) {
        annotationLogger.info("editImage called size=\(data.count)")
        Task {
            await presentEditor(data: data)
        }
    }

    private func presentEditor(data: Data) async {
        guard let image = NSImage(data: data) else {
            alertPresenter.show(message: "Could not load image for annotation.")
            return
        }

        let maxW: CGFloat = 1000
        let maxH: CGFloat = 800
        let imageSize = image.size
        let scale = min(maxW / imageSize.width, maxH / imageSize.height, 1.0)
        let editorSize = NSSize(
            width: min(imageSize.width * scale, maxW),
            height: min(imageSize.height * scale, maxH) + 50
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: editorSize.width, height: editorSize.height),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "SleanShot — Annotate"
        window.minSize = NSSize(width: 400, height: 300)
        window.center()

        enum EditorAction {
            case saved
            case copied
            case discarded
        }

        let action = await withUnsafeContinuation { continuation in
            let hostingView = NSHostingView(
                rootView: AnnotationEditorView(
                    image: image,
                    flattenedSize: imageSize,
                    onSave: { [weak window] annotatedData in
                        guard let window = window else { return }
                        let panel = NSSavePanel()
                        panel.allowedContentTypes = [.png]
                        panel.canCreateDirectories = true
                        panel.nameFieldStringValue = "Screenshot.png"
                        let response = panel.runModal()
                        guard response == .OK, let url = panel.url else {
                            return
                        }
                        do {
                            try annotatedData.write(to: url)
                            continuation.resume(returning: .saved)
                            window.orderOut(nil)
                        } catch {
                            let alert = NSAlert()
                            alert.messageText = "Save failed. Please try again."
                            alert.runModal()
                        }
                    },
                    onCopy: { [weak self, weak window] annotatedData in
                        self?.clipboardService.copyImageData(annotatedData)
                        continuation.resume(returning: .copied)
                        window?.orderOut(nil)
                    },
                    onDiscard: { [weak window] in
                        continuation.resume(returning: .discarded)
                        window?.orderOut(nil)
                    }
                )
            )
            hostingView.frame = NSRect(origin: .zero, size: editorSize)
            hostingView.autoresizingMask = [.width, .height]
            window.contentView = hostingView
            window.makeKeyAndOrderFront(nil)
        }

        annotationLogger.info("editor closed action=\(String(describing: action))")
    }
}

private struct AnnotationEditorView: View {
    let image: NSImage
    let flattenedSize: NSSize
    let onSave: (Data) -> Void
    let onCopy: (Data) -> Void
    let onDiscard: () -> Void

    @State private var drawing = PKDrawing()

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black.opacity(0.05)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                AnnotationCanvasView(drawing: $drawing)
            }

            HStack(spacing: 16) {
                Button("Save") {
                    if let data = flatten() {
                        onSave(data)
                    }
                }
                Button("Copy") {
                    if let data = flatten() {
                        onCopy(data)
                    }
                }
                Button("Discard", role: .destructive) {
                    onDiscard()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
    }

    private func flatten() -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let w = cgImage.width
        let h = cgImage.height
        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w,
            pixelsHigh: h,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        bitmapRep.size = image.size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        image.draw(at: .zero, from: .zero, operation: .copy, fraction: 1.0)
        let uiImage = drawing.image(from: CGRect(x: 0, y: 0, width: w, height: h), scale: 1.0)
        if let cgDrawing = uiImage.cgImage {
            let drawingImage = NSImage(cgImage: cgDrawing, size: image.size)
            drawingImage.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
        NSGraphicsContext.restoreGraphicsState()

        return bitmapRep.representation(using: .png, properties: [:])
    }
}
