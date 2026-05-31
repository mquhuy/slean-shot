import AppKit
import Foundation

/// UserDefaults key holding the user's chosen default save directory for
/// screenshots (stored as a plain filesystem path). Absent/empty means
/// "ask each time" and the save panel opens at its system default location.
let defaultScreenshotDirectoryKey = "defaultScreenshotDirectory"

/// UserDefaults key controlling whether screenshots are written straight to the
/// default save location without showing a save dialog. Only meaningful when a
/// default directory is set; absent/false means "ask each time".
let autoSaveScreenshotsKey = "autoSaveScreenshots"

/// Default filenames and save location for exported screenshots.
enum ScreenshotSavePreferences {
    /// macOS-style default filename, e.g. `Screenshot 2026-05-31 at 14.30.45.png`.
    static func defaultFileName(date: Date = Date(), fileExtension: String = "png") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Screenshot \(formatter.string(from: date)).\(fileExtension)"
    }

    /// User-chosen default save directory, if set and still a reachable folder.
    /// Returns nil when unset so callers fall back to the panel's default.
    static func defaultDirectoryURL(defaults: UserDefaults = .standard) -> URL? {
        guard let path = defaults.string(forKey: defaultScreenshotDirectoryKey),
              !path.isEmpty else {
            return nil
        }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return url
    }

    /// Auto-save target URL when the user opted to skip the save dialog: a
    /// unique file inside the default directory. Returns nil when auto-save is
    /// off or no default directory is set, so callers fall back to a save panel.
    static func autoSaveURL(fileExtension: String = "png",
                            defaults: UserDefaults = .standard) -> URL? {
        guard defaults.bool(forKey: autoSaveScreenshotsKey),
              let directory = defaultDirectoryURL(defaults: defaults) else {
            return nil
        }
        return uniqueURL(in: directory,
                         fileName: defaultFileName(fileExtension: fileExtension),
                         fileExtension: fileExtension)
    }

    /// Returns `directory/fileName`, appending " (2)", " (3)", … before the
    /// extension if a file already exists at that path.
    static func uniqueURL(in directory: URL,
                          fileName: String,
                          fileExtension: String) -> URL {
        let candidate = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            return candidate
        }
        let base = (fileName as NSString).deletingPathExtension
        var index = 2
        while true {
            let next = directory.appendingPathComponent("\(base) (\(index)).\(fileExtension)")
            if !FileManager.default.fileExists(atPath: next.path) {
                return next
            }
            index += 1
        }
    }

    /// Apply the default filename and directory to a save panel.
    @MainActor
    static func configure(_ panel: NSSavePanel,
                          fileExtension: String = "png",
                          defaults: UserDefaults = .standard) {
        panel.nameFieldStringValue = defaultFileName(fileExtension: fileExtension)
        if let directory = defaultDirectoryURL(defaults: defaults) {
            panel.directoryURL = directory
        }
    }
}
