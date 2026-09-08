import Foundation
import ServiceManagement

/// Login item registration.
///
/// Uses `SMAppService.mainApp`, which replaced the long-deprecated
/// `SMLoginItemSetEnabled` / login-item-helper-bundle dance. It registers the app bundle itself,
/// so it only works on a properly bundled and signed build — not on `swift run`.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// - Returns: the state actually achieved, which differs from `enabled` if macOS refused.
    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Lens: could not \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
        return isEnabled
    }
}
