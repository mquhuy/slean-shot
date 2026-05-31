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
                        let url: URL
                        if let target = ScreenshotSavePreferences.autoSaveURL() {
                            url = target
                        } else {
                            let panel = NSSavePanel()
                            panel.allowedContentTypes = [.png]
                            panel.canCreateDirectories = true
                            ScreenshotSavePreferences.configure(panel)
                            guard panel.runModal() == .OK, let chosen = panel.url else {
                                return
                            }
                            url = chosen
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

    @State private var strokes: [Stroke] = []
    @State private var texts: [TextItem] = []
    @State private var editingTextID: UUID? = nil
    @State private var selectedTool: AnnotationTool = .brush
    @State private var selectedColor: Color = .red
    @State private var selectedWidth: CGFloat = 3
    @State private var showColorPopover = false
    @State private var contentSize: CGSize = .zero
    @FocusState private var textFieldFocused: Bool

    private let presetColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .blue, .purple, .pink, .black, .white, .gray
    ]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.05)
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                    AnnotationCanvasView(
                        strokes: $strokes,
                        selectedTool: selectedTool,
                        selectedColor: selectedColor,
                        selectedWidth: selectedWidth,
                        onPlaceText: placeText(at:)
                    )
                    textOverlays
                }
                .onAppear { contentSize = geo.size }
                .onChange(of: geo.size) { _, newSize in
                    contentSize = newSize
                }
            }

            HStack(spacing: 16) {
                Button("Save") {
                    commitText()
                    if let data = flatten() { onSave(data) }
                }
                Button("Copy") {
                    commitText()
                    if let data = flatten() { onCopy(data) }
                }
                Button("Discard", role: .destructive) {
                    onDiscard()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(AnnotationTool.allCases, id: \.self) { tool in
                    Button {
                        selectedTool = tool
                    } label: {
                        Image(systemName: tool.icon)
                            .frame(width: 26, height: 26)
                            .background(selectedTool == tool ? Color.accentColor.opacity(0.25) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help(tool.label)
                }
            }

            Divider().frame(height: 22)

            Button {
                showColorPopover.toggle()
            } label: {
                Circle()
                    .fill(selectedColor)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.gray.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Color")
            .popover(isPresented: $showColorPopover, arrowEdge: .bottom) {
                colorPalette
            }

            Divider().frame(height: 22)

            HStack(spacing: 6) {
                Image(systemName: selectedTool == .text ? "textformat.size" : "lineweight")
                    .foregroundColor(.secondary)
                Slider(value: $selectedWidth, in: 1...20, step: 1).frame(width: 90)
                Text("\(Int(selectedWidth))").font(.caption).foregroundColor(.secondary).frame(width: 20)
            }

            Spacer()

            Button {
                if !strokes.filter({ $0.points.count >= 2 }).isEmpty {
                    // remove last real stroke (keep trailing empty slot if present)
                    if let idx = strokes.lastIndex(where: { $0.points.count >= 2 }) {
                        strokes.remove(at: idx)
                    }
                } else if !texts.isEmpty {
                    texts.removeLast()
                }
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .help("Undo")

            Button {
                strokes.removeAll()
                texts.removeAll()
                editingTextID = nil
            } label: {
                Image(systemName: "trash")
            }
            .help("Clear all")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var colorPalette: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Colors").font(.caption).foregroundColor(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 8), count: 6), spacing: 8) {
                ForEach(presetColors.indices, id: \.self) { i in
                    let c = presetColors[i]
                    Circle()
                        .fill(c)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(selectedColor == c ? Color.accentColor : Color.gray.opacity(0.4),
                                                 lineWidth: selectedColor == c ? 2.5 : 1))
                        .onTapGesture {
                            selectedColor = c
                            showColorPopover = false
                        }
                }
            }
            Divider()
            ColorPicker("Custom", selection: $selectedColor, supportsOpacity: false)
        }
        .padding(12)
        .frame(width: 230)
    }

    // MARK: Text overlays

    @ViewBuilder
    private var textOverlays: some View {
        ForEach(texts) { t in
            if t.id == editingTextID {
                TextField("Text", text: bindingForText(t.id))
                    .font(.system(size: t.fontSize, weight: .semibold))
                    .foregroundColor(t.color)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 80, alignment: .leading)
                    .fixedSize()
                    .focused($textFieldFocused)
                    .onSubmit { commitText() }
                    .offset(x: t.position.x, y: t.position.y)
            } else if !t.text.isEmpty {
                Text(t.text)
                    .font(.system(size: t.fontSize, weight: .semibold))
                    .foregroundColor(t.color)
                    .fixedSize()
                    .offset(x: t.position.x, y: t.position.y)
                    .allowsHitTesting(false)
            }
        }
    }

    private func bindingForText(_ id: UUID) -> Binding<String> {
        Binding(
            get: { texts.first(where: { $0.id == id })?.text ?? "" },
            set: { newValue in
                if let idx = texts.firstIndex(where: { $0.id == id }) {
                    texts[idx].text = newValue
                }
            }
        )
    }

    private func placeText(at location: CGPoint) {
        commitText()
        let item = TextItem(text: "", position: location, color: selectedColor, fontSize: selectedWidth * 5)
        texts.append(item)
        editingTextID = item.id
        DispatchQueue.main.async { textFieldFocused = true }
    }

    private func commitText() {
        defer {
            editingTextID = nil
            textFieldFocused = false
        }
        guard let id = editingTextID, let idx = texts.firstIndex(where: { $0.id == id }) else { return }
        if texts[idx].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            texts.remove(at: idx)
        }
    }

    // MARK: Flatten

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
        cgCtx.setLineCap(.round)
        cgCtx.setLineJoin(.round)

        // map a display point -> image pixel point (flipped y for CG)
        func mapped(_ p: CGPoint) -> CGPoint {
            CGPoint(x: (p.x - offsetX) * scaleX, y: CGFloat(h) - (p.y - offsetY) * scaleY)
        }

        for stroke in strokes where stroke.points.count >= 2 {
            cgCtx.setStrokeColor(stroke.color.cgColor ?? CGColor.black)
            cgCtx.setLineWidth(stroke.width * max(scaleX, scaleY))
            let pts = stroke.points.map(mapped)
            switch stroke.tool {
            case .brush:
                cgCtx.beginPath()
                cgCtx.move(to: pts[0])
                for p in pts.dropFirst() { cgCtx.addLine(to: p) }
                cgCtx.strokePath()
            case .line:
                cgCtx.beginPath()
                cgCtx.move(to: pts[0])
                cgCtx.addLine(to: pts[1])
                cgCtx.strokePath()
            case .arrow:
                let start = pts[0], end = pts[1]
                cgCtx.beginPath()
                cgCtx.move(to: start)
                cgCtx.addLine(to: end)
                let angle = atan2(end.y - start.y, end.x - start.x)
                let headLen = max(stroke.width * max(scaleX, scaleY) * 4, 12)
                let ha: CGFloat = .pi / 6
                cgCtx.move(to: end)
                cgCtx.addLine(to: CGPoint(x: end.x - headLen * cos(angle - ha), y: end.y - headLen * sin(angle - ha)))
                cgCtx.move(to: end)
                cgCtx.addLine(to: CGPoint(x: end.x - headLen * cos(angle + ha), y: end.y - headLen * sin(angle + ha)))
                cgCtx.strokePath()
            case .circle:
                let rect = CGRect(x: min(pts[0].x, pts[1].x),
                                  y: min(pts[0].y, pts[1].y),
                                  width: abs(pts[1].x - pts[0].x),
                                  height: abs(pts[1].y - pts[0].y))
                cgCtx.beginPath()
                cgCtx.addEllipse(in: rect)
                cgCtx.strokePath()
            case .text:
                break
            }
        }

        // text: draw with AppKit (non-flipped context, point = lower-left of text)
        for t in texts where !t.text.isEmpty {
            let fontSize = t.fontSize * max(scaleX, scaleY)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: NSColor(t.color)
            ]
            let str = t.text as NSString
            let textHeight = str.size(withAttributes: attrs).height
            let topX = (t.position.x - offsetX) * scaleX
            let topYFromTop = (t.position.y - offsetY) * scaleY
            let drawY = CGFloat(h) - topYFromTop - textHeight
            str.draw(at: CGPoint(x: topX, y: drawY), withAttributes: attrs)
        }

        NSGraphicsContext.restoreGraphicsState()
        return bitmapRep.representation(using: .png, properties: [:])
    }
}
