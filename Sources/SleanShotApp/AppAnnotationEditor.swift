import AppKit
import OSLog
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
                            continuation.resume(returning: EditorAction.saved)
                            window.orderOut(nil)
                        } catch {
                            let alert = NSAlert()
                            alert.messageText = "Save failed. Please try again."
                            alert.runModal()
                        }
                    },
                    onCopy: { [weak self, weak window] annotatedData in
                        self?.clipboardService.copyImageData(annotatedData)
                        continuation.resume(returning: EditorAction.copied)
                        window?.orderOut(nil)
                    },
                    onDiscard: { [weak window] in
                        continuation.resume(returning: EditorAction.discarded)
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

    @State private var lines: [Line] = []
    @State private var contentSize: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.05)
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                    AnnotationCanvasView(lines: $lines)
                }
                .onAppear { contentSize = geo.size }
                .onChange(of: geo.size) { _, newSize in
                    contentSize = newSize
                }
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

        guard contentSize.width > 0, contentSize.height > 0 else { return nil }

        let imageSize = image.size
        let displayScale = min(contentSize.width / imageSize.width, contentSize.height / imageSize.height, 1.0)
        let displayW = imageSize.width * displayScale
        let displayH = imageSize.height * displayScale
        let offsetX = (contentSize.width - displayW) / 2
        let offsetY = (contentSize.height - displayH) / 2

        let scaleX = CGFloat(w) / displayW
        let scaleY = CGFloat(h) / displayH

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
        guard let ctx = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = ctx

        image.draw(at: .zero, from: .zero, operation: .copy, fraction: 1.0)

        let cgCtx = ctx.cgContext
        cgCtx.setLineCap(CGLineCap.round)
        cgCtx.setLineJoin(CGLineJoin.round)

        for line in lines where line.points.count > 1 {
            let color = line.color.cgColor ?? CGColor.black
            cgCtx.setStrokeColor(color)
            cgCtx.setLineWidth(line.width * max(scaleX, scaleY))

            cgCtx.beginPath()
            let first = line.points[0]
            cgCtx.move(to: CGPoint(
                x: (first.x - offsetX) * scaleX,
                y: CGFloat(h) - (first.y - offsetY) * scaleY
            ))
            for point in line.points.dropFirst() {
                cgCtx.addLine(to: CGPoint(
                    x: (point.x - offsetX) * scaleX,
                    y: CGFloat(h) - (point.y - offsetY) * scaleY
                ))
            }
            cgCtx.strokePath()
        }

        NSGraphicsContext.restoreGraphicsState()
        return bitmapRep.representation(using: .png, properties: [:])
    }
}
