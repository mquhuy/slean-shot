import SwiftUI

struct SettingsView: View {
    @AppStorage("autoCopyScreenshotToClipboard") private var autoCopyScreenshotToClipboard = true

    var body: some View {
        Form {
            Toggle("Automatically copy screenshots to clipboard", isOn: $autoCopyScreenshotToClipboard)
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }
}
