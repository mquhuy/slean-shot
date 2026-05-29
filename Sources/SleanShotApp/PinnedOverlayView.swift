import SwiftUI
import SleanShotCore

struct PinnedOverlayView: View {
    let item: CaptureItem
    let actions: OverlayActions
    
    var nsImage: NSImage? {
        guard let data = item.imageData else { return nil }
        return NSImage(data: data)
    }
    
    var body: some View {
        ZStack {
            if let img = nsImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack(spacing: 8) {
                actionButton(systemName: "doc.on.doc", action: actions.copy)
                actionButton(systemName: "square.and.arrow.down", action: actions.save)
                actionButton(systemName: "trash", action: actions.drop)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
            .offset(x: -4, y: -4)
            
            Button(action: actions.drop) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(8)
            .offset(x: 4, y: -4)
        }
        .padding(20) // Room for shadow
    }

    private func actionButton(systemName: String, action: @escaping @MainActor @Sendable () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
}
