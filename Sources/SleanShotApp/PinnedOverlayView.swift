import SwiftUI
import SleanShotCore

struct PinnedOverlayView: View {
    let item: CaptureItem
    let actions: OverlayActions
    let previewSize: CGSize
    @State private var isHovering = false
    
    private var isScreenshot: Bool { item.kind == .screenshot }

    private func handleTap() {
        if isScreenshot {
            actions.edit()
        } else if let url = item.fileURL {
            NSWorkspace.shared.open(url)
        }
    }

    var nsImage: NSImage? {
        guard let data = item.imageData ?? item.thumbnailData else { return nil }
        return NSImage(data: data)
    }

    var body: some View {
        ZStack {
            if let img = nsImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: previewSize.width, height: previewSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    )
                    .overlay {
                        if !isScreenshot {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(radius: 3)
                        }
                    }
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                    .onTapGesture { handleTap() }
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isHovering = hovering
                        }
                    }
                    .overlay(alignment: .top) {
                        if isHovering {
                            Text(isScreenshot ? "Edit" : "Play")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.black.opacity(0.7)))
                                .offset(y: -8)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.8))
                    .frame(width: previewSize.width, height: previewSize.height)
                    .overlay {
                        if !isScreenshot {
                            Image(systemName: "film")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
            }

            HStack(spacing: 8) {
                actionButton(systemName: "doc.on.doc", accessibilityLabel: "Copy", action: actions.copy)
                actionButton(systemName: "square.and.arrow.down", accessibilityLabel: "Save", action: actions.save)
                actionButton(systemName: "trash", accessibilityLabel: "Drop", action: actions.drop)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
            .offset(x: -4, y: -4)
            
        }
        .padding(20) // Room for shadow
    }

    private func actionButton(systemName: String, accessibilityLabel: String, action: @escaping @MainActor @Sendable () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
