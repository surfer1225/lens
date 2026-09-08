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
