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
                    .frame(maxWidth: 300, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 10)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 300, height: 200)
            }
            
            Button(action: closeAction) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .padding(4)
        }
        .padding(16) // Room for shadow
    }
}
