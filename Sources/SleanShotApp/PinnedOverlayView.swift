import SwiftUI
import SleanShotCore

struct PinnedOverlayView: View {
    let item: CaptureItem
    let closeAction: () -> Void
    
    var nsImage: NSImage? {
        guard let data = item.imageData else { return nil }
        return NSImage(data: data)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
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
            
            Button(action: closeAction) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(8)
            .offset(x: 4, y: -4)
        }
        .padding(20) // Room for shadow
    }
}
