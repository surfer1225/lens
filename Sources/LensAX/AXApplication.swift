import AppKit
import ApplicationServices
import LensCore

/// Attribute names Apple never exported as constants.
enum AXAttribute {
    /// Set by VoiceOver and by apps such as Chrome and Electron shells. While it is on, those
    /// apps animate or mis-apply position and size changes.
    static let enhancedUserInterface = "AXEnhancedUserInterface"
    /// Native (green-button) fullscreen. Position and size changes are ignored while it is true.
    static let fullScreen = "AXFullScreen"
}

/// The Accessibility view of a running application.
@MainActor
public struct AXApplication {
    public let element: AXUIElement
    public let processIdentifier: pid_t
    public let bundleIdentifier: String?
    public let localizedName: String?

    public init(running: NSRunningApplication) {
        self.element = AXUIElementCreateApplication(running.processIdentifier)
        self.processIdentifier = running.processIdentifier
        self.bundleIdentifier = running.bundleIdentifier
        self.localizedName = running.localizedName
    }

    /// The application the user is currently working in.
    public static var frontmost: AXApplication? {
        NSWorkspace.shared.frontmostApplication.map(AXApplication.init(running:))
    }

    /// The window a keystroke would go to.
    ///
    /// Falls back to the main window, because a few apps report no focused window while a
    /// palette or toolbar holds focus.
    public var focusedWindow: AXWindow? {
        if let focused: AXUIElement = element.value(kAXFocusedWindowAttribute) {
            return AXWindow(element: focused, application: self)
        }
        if let main: AXUIElement = element.value(kAXMainWindowAttribute) {
            return AXWindow(element: main, application: self)
        }
        return nil
    }

    /// Every window this application currently has, in the order the system reports them.
    ///
    /// That order is stable for a given set of windows, which is what makes it usable as a
    /// fallback identity when window titles cannot disambiguate.
    public var allWindows: [AXWindow] {
        guard let elements: [AXUIElement] = element.value(kAXWindowsAttribute) else { return [] }
        return elements.map { AXWindow(element: $0, application: self) }
    }

    /// Every window of every ordinary application, paired with its position in its own app's
    /// window list.
    ///
    /// Skips agents and background-only processes, which have no user-visible windows to arrange,
    /// and Lens itself.
    public static func allVisibleWindows() -> [(window: AXWindow, index: Int)] {
        let ourBundleID = Bundle.main.bundleIdentifier

        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != ourBundleID }
            .flatMap { running -> [(AXWindow, Int)] in
                let app = AXApplication(running: running)
                // Sweeping every app is the one place a single unresponsive process could stall
                // the main thread: Accessibility calls block, and the default timeout is several
                // seconds. Cap it — a beachballing app should cost us a dropped window, not a
                // frozen menu bar.
                app.setMessagingTimeout(0.25)
                return app.allWindows.enumerated().map { entry in
                    // Set on each window too: it isn't documented to inherit the app's timeout.
                    AXUIElementSetMessagingTimeout(entry.element.element, 0.25)
                    return (entry.element, entry.offset)
                }
            }
    }

    /// Bounds how long any Accessibility call to this application may block.
    public func setMessagingTimeout(_ seconds: Float) {
        AXUIElementSetMessagingTimeout(element, seconds)
    }

    /// See `AXAttribute.enhancedUserInterface`.
    public var enhancedUserInterface: Bool {
        get { element.boolValue(AXAttribute.enhancedUserInterface) ?? false }
        nonmutating set {
            element.setValue(AXAttribute.enhancedUserInterface, NSNumber(value: newValue))
        }
    }

    /// Runs `body` with enhanced user interface temporarily switched off, restoring it
    /// afterwards even if `body` throws.
    ///
    /// Restoring matters: leaving it off would silently degrade VoiceOver for that app.
    public func withEnhancedUserInterfaceDisabled<T>(_ body: () throws -> T) rethrows -> T {
        let wasEnabled = enhancedUserInterface
        if wasEnabled { enhancedUserInterface = false }
        defer { if wasEnabled { enhancedUserInterface = true } }
        return try body()
    }
}
