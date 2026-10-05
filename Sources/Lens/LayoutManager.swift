import AppKit
import LensAX
import LensCore
import Observation

/// Remembers where your windows live in each display setup, and puts them back when you return
/// to one.
///
/// The problem this solves: unplug a monitor and macOS piles every window onto the remaining
/// display. Plug it back in and they stay piled. macOS has never restored them, so Lens does.
///
/// The mechanism is deliberately simple. While a display configuration is stable, Lens
/// periodically records where everything is, keyed by a fingerprint of that configuration. When
/// the configuration changes, it looks up whatever it last recorded for the *new* setup and
/// restores it. Because the recording happened before the change, redocking finds a layout that
/// describes the desk you are returning to. Sleep, wake and displays that briefly drop out are
/// handled too; `MemoryPolicy` holds those rules, and this class carries out its decisions.
@MainActor
@Observable
final class LayoutManager {
    /// How often the current arrangement is recorded while the display setup is stable.
    private static let captureInterval: TimeInterval = 30

    /// macOS emits several screen-change notifications during one plug or unplug. Wait for them
    /// to stop before deciding anything has actually changed.
    private static let changeDebounce: TimeInterval = 1.5

    private static let storageKey = "layouts"

    private(set) var library: LayoutLibrary
    private(set) var currentFingerprint: DisplayFingerprint

    /// Set by `AppModel` from user settings.
    var isEnabled: Bool = true
    var settings: Settings = .default

    private var policy: MemoryPolicy
    private var captureTimer: Timer?
    private var pendingChange: DispatchWorkItem?

    /// Window titles are remembered only as keyed digests; see `TitleDigest`.
    private let titles: TitleDigest
    private static let titleKeyKey = "layoutTitleKey"

    init() {
        let setup = Self.fingerprint()
        let titles = TitleDigest(key: Self.titleKey())
        self.titles = titles
        // Layouts saved by earlier versions hold raw titles: convert them once, and save.
        let stored = Self.load()
        let converted = stored.mappingTitles(titles.digest)
        self.library = converted
        self.currentFingerprint = setup
        self.policy = MemoryPolicy(setup: setup)
        if converted != stored {
            persist()
        }
    }

    // MARK: - Lifecycle

    func start() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenParametersChanged() }
        }

        // The Mac sleeping and its displays sleeping both scatter windows, so both count.
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.handle(.sleep) }
            }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.handle(.wake) }
            }
        }

        captureTimer = Timer.scheduledTimer(
            withTimeInterval: Self.captureInterval, repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handle(.tick(setup: Self.fingerprint())) }
        }
    }

    // MARK: - Events

    private func screenParametersChanged() {
        handle(.displaysChanging(setup: Self.fingerprint()))

        // Coalesce the burst of notifications a single plug event produces.
        pendingChange?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.handle(.displaysSettled(setup: Self.fingerprint())) }
        }
        pendingChange = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.changeDebounce, execute: work)
    }

    private func handle(_ event: MemoryPolicy.Event) {
        let action = policy.handle(event)
        currentFingerprint = policy.currentSetup

        switch action {
        case .none:
            break
        case .capture:
            captureIfAllowed()
        case .restore(let setup):
            if isEnabled, let saved = library.layout(for: setup) { apply(saved) }
        }

        // The post-wake restore is due sooner than the regular timer would notice.
        if case .wake = event, let due = policy.wakeRestoreDue {
            let delay = max(0, due.timeIntervalSinceNow)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                MainActor.assumeIsolated { self?.handle(.tick(setup: Self.fingerprint())) }
            }
        }
    }

    // MARK: - Capture

    private func captureIfAllowed() {
        guard isEnabled, AXIsProcessTrusted() else { return }
        guard Self.fingerprint() == currentFingerprint else { return }

        let layout = captureCurrentLayout()
        // `store` ignores empty layouts, so a moment with no windows cannot erase a good one.
        library.store(layout)
        persist()
    }

    /// Records where every arrangeable window currently is.
    func captureCurrentLayout() -> Layout {
        var snapshots = [WindowSnapshot]()

        for (window, index) in AXApplication.allVisibleWindows() {
            guard let bundleID = window.application.bundleIdentifier,
                  !settings.excludes(bundleID: bundleID),
                  window.isArrangeable,
                  !window.isFullscreen,
                  let frame = window.frame, frame.isReasonable
            else { continue }

            snapshots.append(
                WindowSnapshot(
                    bundleID: bundleID,
                    title: titles.digest(window.title ?? ""),
                    index: index,
                    frame: frame
                )
            )
        }

        return Layout(fingerprint: currentFingerprint, snapshots: snapshots)
    }

    // MARK: - Restore

    /// Applies a remembered layout to the windows open right now.
    @discardableResult
    func apply(_ layout: Layout) -> Int {
        guard AXIsProcessTrusted() else { return 0 }

        // Build the live list in the same order the matcher will index into.
        let windows = AXApplication.allVisibleWindows()
            .filter { $0.window.isArrangeable && !$0.window.isFullscreen }

        let live = windows.enumerated().compactMap { offset, entry -> LiveWindow? in
            guard let bundleID = entry.window.application.bundleIdentifier,
                  !settings.excludes(bundleID: bundleID)
            else { return nil }
            return LiveWindow(
                id: offset,
                bundleID: bundleID,
                title: titles.digest(entry.window.title ?? ""),
                index: entry.index
            )
        }

        let plan = LayoutMatcher.plan(restoring: layout, onto: live)
        guard !plan.isEmpty else { return 0 }

        // Group by application so the enhanced-user-interface workaround is toggled once per
        // app rather than once per window.
        let byApp = Dictionary(grouping: plan) { windows[$0.windowID].window.application.processIdentifier }

        var moved = 0
        for (_, assignments) in byApp {
            guard let first = assignments.first else { continue }
            let app = windows[first.windowID].window.application

            app.withEnhancedUserInterfaceDisabled {
                for assignment in assignments {
                    let window = windows[assignment.windowID].window
                    let bounds = ScreenDetector.screen(containing: assignment.frame)
                        .map { ScreenDetector.usableFrame(of: $0, settings: settings) }
                        ?? assignment.frame
                    if window.setFrame(assignment.frame, constrainedTo: bounds) != nil {
                        moved += 1
                    }
                }
            }
        }

        return moved
    }

    // MARK: - Commands

    /// Records the current arrangement for this display setup, replacing whatever was there.
    @discardableResult
    func saveCurrentLayout() -> Int {
        let layout = captureCurrentLayout()
        library.store(layout)
        persist()
        return layout.snapshots.count
    }

    @discardableResult
    func restoreSavedLayout() -> Int {
        guard let saved = library.layout(for: currentFingerprint) else { return 0 }
        return apply(saved)
    }

    func forgetCurrentLayout() {
        library.forget(currentFingerprint)
        persist()
    }

    func forgetAllLayouts() {
        library.removeAll()
        persist()
    }

    var hasSavedLayoutForCurrentSetup: Bool {
        library.layout(for: currentFingerprint) != nil
    }

    /// Human-readable description of the current setup, for the menu and Settings.
    var currentSetupDescription: String {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return "No displays" }
        if screens.count == 1 { return screens[0].localizedName }
        return "\(screens.count) displays: "
            + screens.map(\.localizedName).sorted().joined(separator: ", ")
    }

    // MARK: - Fingerprint

    static func fingerprint() -> DisplayFingerprint {
        DisplayFingerprint(
            screens: NSScreen.screens.map {
                ScreenDescriptor(name: $0.localizedName, frame: $0.frame)
            }
        )
    }

    // MARK: - Persistence

    /// The per-Mac key for title digests, created on first use.
    private static func titleKey() -> Data {
        if let key = UserDefaults.standard.data(forKey: titleKeyKey), key.count == 32 {
            return key
        }
        let key = TitleDigest.makeKey()
        UserDefaults.standard.set(key, forKey: titleKeyKey)
        return key
    }

    private static func load() -> LayoutLibrary {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(LayoutLibrary.self, from: data)
        else { return LayoutLibrary() }
        return decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(library) else {
            NSLog("Lens: couldn't save remembered layouts")
            return
        }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
