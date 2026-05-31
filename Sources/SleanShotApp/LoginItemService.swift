import Foundation
import ServiceManagement

/// Registers/unregisters SleanShot as a "start at login" item via the modern
/// `SMAppService` API (macOS 13+). The system, not UserDefaults, is the source
/// of truth for the current state.
enum LoginItemService {
    /// Whether SleanShot is currently set to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Enable or disable launch at login. Throws if the system rejects the change.
    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            // register() is a no-op error if already enabled; guard to stay quiet.
            guard service.status != .enabled else { return }
            try service.register()
        } else {
            guard service.status == .enabled else { return }
            try service.unregister()
        }
    }
}
