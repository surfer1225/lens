import AppKit
import ApplicationServices
import LensCore

/// A single window belonging to another application.
///
/// All frames exposed here are in Cocoa orientation (origin bottom-left); the conversion to and
/// from the Accessibility API's top-left space happens inside this type.
@MainActor
public struct AXWindow {
    public let element: AXUIElement
    public let application: AXApplication

    public init(element: AXUIElement, application: AXApplication) {
        self.element = element
        self.application = application
    }

    // MARK: - Geometry

    /// Current frame in Cocoa orientation, or `nil` if the window will not report its geometry.
    public var frame: CGRect? {
        guard let position = element.position, let size = element.size else { return nil }
        return ScreenDetector.flip(CGRect(origin: position, size: size))
    }

    public var isMovable: Bool { element.isSettable(kAXPositionAttribute) }
    public var isResizable: Bool { element.isSettable(kAXSizeAttribute) }

    public var subrole: String? { element.value(kAXSubroleAttribute) }
    public var title: String? { element.value(kAXTitleAttribute) }

    /// The documented AX subroles for windows the system owns. Rearranging these either fails
    /// outright or leaves the UI in a bad state.
    private static let unmanageableSubroles: Set<String> = [
        "AXSystemDialog",
        "AXSystemFloatingWindow",
    ]

    /// Whether this is a window Lens should touch at all.
    ///
    /// The movable/resizable checks alone filter out most sheets and fixed-size panels; the
    /// subrole check catches the system-owned windows that claim to be resizable.
    public var isArrangeable: Bool {
        guard isMovable, isResizable else { return false }
        if let subrole, Self.unmanageableSubroles.contains(subrole) { return false }
        return true
    }

    // MARK: - Fullscreen

    public var isFullscreen: Bool {
        element.boolValue(AXAttribute.fullScreen) ?? false
    }

    /// Leaves native fullscreen, returning `true` if it actually did something.
    ///
    /// macOS silently ignores position and size changes on a fullscreen window, so callers must
    /// do this first or the action appears to do nothing at all.
    @discardableResult
    public func exitFullscreen() -> Bool {
        guard isFullscreen, element.isSettable(AXAttribute.fullScreen) else { return false }
        return element.setValue(AXAttribute.fullScreen, NSNumber(value: false))
    }

    // MARK: - Identity

    /// A key that stays stable for this window across key presses.
    ///
    /// Prefers the real `CGWindowID`. When that is unavailable the fallback hashes the process
    /// and title, which is good enough to key undo history but is flagged `isExact: false` so
    /// `CycleState` will not cycle on it — two untitled windows of one app would otherwise
    /// collide and cycle each other's sizes.
    public var identifier: WindowID {
        if let id = PrivateAX.windowID(of: element) {
            return WindowID(raw: UInt64(id), isExact: true)
        }

        var hasher = Hasher()
        hasher.combine(application.processIdentifier)
        hasher.combine(title ?? "")
        return WindowID(raw: UInt64(bitPattern: Int64(hasher.finalize())), isExact: false)
    }

    // MARK: - Moving

    /// Moves and resizes the window, working around the apps that fight back.
    ///
    /// Returns the frame the window actually ended up at, which is not always the one requested.
    ///
    /// - Parameter constrainedTo: the usable area of the destination screen, used to pull the
    ///   window back on-screen if the app refuses the requested size.
    @discardableResult
    public func setFrame(_ target: CGRect, constrainedTo usableFrame: CGRect) -> CGRect? {
        guard isArrangeable else { return nil }

        let axTarget = ScreenDetector.flip(target)

        // Size, then position, then size again. Apps that quantise their size (Terminal and
        // iTerm size in whole character cells) accept a different size than we asked for, which
        // shifts where the window ends up; the second size pass settles it after the move.
        element.setSize(axTarget.size)
        element.setPosition(axTarget.origin)
        element.setSize(axTarget.size)

        guard var settled = frame else { return nil }

        // The app kept a size of its own choosing — a minimum size, or cell quantisation. Honour
        // its size but put the window back inside the screen.
        if abs(settled.width - target.width) > 1 || abs(settled.height - target.height) > 1 {
            let corrected = RectCalculator.clamp(
                CGRect(origin: target.origin, size: settled.size),
                to: usableFrame
            )
            if abs(corrected.minX - settled.minX) > 1 || abs(corrected.minY - settled.minY) > 1 {
                element.setPosition(ScreenDetector.flip(corrected).origin)
                settled = frame ?? corrected
            }
        }

        return settled
    }
}
