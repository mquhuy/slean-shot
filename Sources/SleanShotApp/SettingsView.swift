import SwiftUI

struct SettingsView: View {
    @AppStorage("autoCopyScreenshotToClipboard") private var autoCopyScreenshotToClipboard = true
    @AppStorage("showRecordingBorder") private var showRecordingBorder = true

    var body: some View {
        Form {
            Toggle("Automatically copy screenshots to clipboard", isOn: $autoCopyScreenshotToClipboard)
            Toggle("Show a border around the recording area", isOn: $showRecordingBorder)
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }
}
