import AppKit
import SwiftUI

/// A small floating panel shown while recording, giving the user an obvious way
/// to stop. It is a SleanShot-owned window, so it is automatically excluded from
/// the recording by `SCShareableContent.sleanShotWindows()`.
@MainActor
final class RecordingControlPanel {
    private var window: NSWindow?

    func show(onStop: @escaping @MainActor () -> Void) {
        guard window == nil else { return }

        let size = NSSize(width: 200, height: 56)
        let panel = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true

        panel.contentView = NSHostingView(rootView: RecordingControlView(onStop: onStop))

        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - size.width / 2
            let y = screen.visibleFrame.maxY - size.height - 24
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        window = panel
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

private struct RecordingControlView: View {
    let onStop: @MainActor () -> Void
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .opacity(pulse ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)

            Text("Recording")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button { onStop() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.red))
            }
            .buttonStyle(.plain)
            .help("Stop recording")
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.78))
        )
        .onAppear { pulse = true }
    }
}
