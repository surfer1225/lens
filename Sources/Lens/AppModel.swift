import AppKit
import ApplicationServices
import KeyboardShortcuts
import LensAX
import LensCore
import Observation

/// Application-wide state: settings, permission status, and the hotkey registration.
@MainActor
@Observable
final class AppModel {
    private static let settingsKey = "settings"

    var settings: Settings {
        didSet {
            guard settings != oldValue else { return }
            dispatcher.settings = settings
            layouts.settings = settings
            layouts.isEnabled = settings.automaticLayoutRestore
            persist()
        }
    }

    let authorizer = AccessibilityAuthorizer()
    let layouts = LayoutManager()

    /// Mirrors `SMAppService`, which is the source of truth; kept as state so the toggle in
    /// Settings stays in sync when macOS refuses a change.
    var launchesAtLogin: Bool {
        didSet {
            guard launchesAtLogin != oldValue else { return }
            let achieved = LaunchAtLogin.set(launchesAtLogin)
            if achieved != launchesAtLogin { launchesAtLogin = achieved }
        }
    }

    private let dispatcher: ActionDispatcher
    private var hotkeysRegistered = false

    init() {
        let loaded = Self.loadSettings()
        self.settings = loaded
        self.dispatcher = ActionDispatcher(settings: loaded)
        self.launchesAtLogin = LaunchAtLogin.isEnabled
    }

    // MARK: - Lifecycle

    func start() {
        // Claim the hotkeys immediately, whether or not Accessibility has been granted yet.
        //
        // Deferring registration until trust arrives seems tidier, but it fails silently in the
        // worst possible way: with no hotkey registered, the keystroke falls straight through to
        // the frontmost app, where ⌥⌘← is "previous tab" in most browsers and "back" elsewhere.
        // The app looks broken and the cause is invisible. Registering up front means an
        // untrusted press beeps instead (see ActionDispatcher.perform), which is diagnosable.
        registerHotkeys()

        layouts.settings = settings
        layouts.isEnabled = settings.automaticLayoutRestore
        layouts.start()

        if !authorizer.refresh() {
            authorizer.request()
            promptForAccessibility()
        }
    }

    /// Binds every action to its shortcut. Safe to call more than once.
    private func registerHotkeys() {
        guard !hotkeysRegistered else { return }
        hotkeysRegistered = true

        for action in WindowAction.allCases {
            KeyboardShortcuts.onKeyDown(for: Shortcuts.name(for: action)) { [weak self] in
                MainActor.assumeIsolated {
                    self?.perform(action)
                }
            }
        }
    }

    func perform(_ action: WindowAction) {
        dispatcher.perform(action)
    }

    // MARK: - Permission

    /// macOS shows its own Accessibility prompt only once per app, and never explains what the
    /// app will do with the access. This says so, and offers a direct route to the right pane.
    private func promptForAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Lens needs Accessibility access"
        alert.informativeText = """
            Lens moves and resizes windows through macOS's Accessibility API, which requires \
            your permission.

            Open System Settings → Privacy & Security → Accessibility and switch on Lens. \
            Shortcuts start working the moment you do — no need to restart.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            authorizer.openSystemSettings()
        }
    }

    // MARK: - Persistence

    private static func loadSettings() -> Settings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let decoded = try? Settings.from(jsonData: data)
        else { return .default }
        return decoded
    }

    private func persist() {
        guard let data = try? settings.jsonData() else { return }
        UserDefaults.standard.set(data, forKey: Self.settingsKey)
    }

    // MARK: - Import / export

    enum ImportError: LocalizedError {
        case tooLarge(bytes: Int)
        case notAFile

        var errorDescription: String? {
            switch self {
            case .notAFile:
                "That isn't a regular file, so it can't be a Lens configuration."
            case .tooLarge(let bytes):
                "That file is \(bytes / 1024) KB. A Lens configuration is well under 64 KB, so "
                    + "this is probably not one."
            }
        }
    }

    /// The exported file contains your gaps, resize step, and the bundle identifiers of any
    /// apps you have excluded. Layout memory (window positions, with titles stored only as
    /// digests) is never exported.
    func exportSettings(to url: URL) throws {
        try settings.jsonData().write(to: url, options: .atomic)
    }

    func importSettings(from url: URL) throws {
        // Read with a ceiling rather than slurping whatever the user picked: a settings file is
        // a few hundred bytes, and pointing this at a multi-gigabyte file should fail cleanly
        // instead of trying to hold it in memory.
        let maximumBytes = 64 * 1024
        // Check before reading: a FIFO or device file would otherwise block or never end.
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw ImportError.notAFile }
        if let size = values.fileSize, size > maximumBytes {
            throw ImportError.tooLarge(bytes: size)
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else {
            throw ImportError.tooLarge(bytes: data.count)
        }

        settings = try Settings.from(jsonData: data)
    }

    func restoreDefaults() {
        settings = .default
        Shortcuts.resetAllToDefaults()
    }
}
