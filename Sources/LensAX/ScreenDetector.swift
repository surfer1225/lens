import AppKit
import CoreGraphics
import LensCore

/// Bridges between Cocoa's screen geometry and the Accessibility API's.
///
/// This is the only place in Lens that knows the two coordinate systems disagree.
@MainActor
public enum ScreenDetector {
    /// The screen the Accessibility API measures everything from: the one whose origin is (0, 0),
    /// which is also the one carrying the menu bar.
    ///
    /// Deliberately *not* `NSScreen.main` — that is the screen with the focused window, which
    /// changes as you work and would corrupt the coordinate flip on multi-display setups.
    public static var primaryScreen: NSScreen? {
        NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.screens.first
    }

    /// Converts between Cocoa (origin bottom-left, y up) and Accessibility (origin top-left of
    /// the primary screen, y down).
    ///
    /// The transform is its own inverse, so one function serves both directions.
    public static func flip(_ rect: CGRect) -> CGRect {
        guard let primary = primaryScreen else { return rect }
        return CGRect(
            x: rect.minX,
            y: primary.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    /// Screens in physical left-to-right, bottom-to-top order.
    ///
    /// `NSScreen.screens` order reflects the display registration order, not the arrangement, so
    /// Next/Previous Display would jump around without this.
    public static var orderedScreens: [NSScreen] {
        NSScreen.screens.sorted { lhs, rhs in
            if lhs.frame.minX != rhs.frame.minX { return lhs.frame.minX < rhs.frame.minX }
            return lhs.frame.minY < rhs.frame.minY
        }
    }

    /// The screen a window is mostly on, by overlapping area.
    public static func screen(containing rect: CGRect) -> NSScreen? {
        let best = NSScreen.screens.max { lhs, rhs in
            overlap(rect, lhs.frame) < overlap(rect, rhs.frame)
        }
        // A window dragged entirely off every display has zero overlap everywhere; fall back
        // rather than dumping it on whichever screen sorted last.
        if let best, overlap(rect, best.frame) > 0 { return best }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private static func overlap(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        return intersection.width * intersection.height
    }

    /// The area of a screen a window may actually occupy.
    ///
    /// `visibleFrame` already excludes the menu bar and Dock. Stage Manager's strip is *not*
    /// excluded, so reserve it here when the feature is on.
    public static func usableFrame(of screen: NSScreen, settings: Settings) -> CGRect {
        var frame = screen.visibleFrame

        if settings.stageManagerInset > 0, isStageManagerEnabled {
            let inset = min(CGFloat(settings.stageManagerInset), frame.width / 2)
            frame.origin.x += inset
            frame.size.width -= inset
        }
        return frame
    }

    /// Stage Manager state, read straight from WindowManager's defaults domain — there is no
    /// public API for it.
    public static var isStageManagerEnabled: Bool {
        UserDefaults(suiteName: "com.apple.WindowManager")?.bool(forKey: "GloballyEnabled") ?? false
    }

    /// The display physically beyond `edge` of `screen`, or `nil` if there is none that way.
    ///
    /// Deliberately does not wrap: pressing Left Half twice on the leftmost display should fall
    /// back to cycling sizes rather than flinging the window to the far right of the desk.
    ///
    /// Candidates must also overlap `screen` on the perpendicular axis, so a display stacked
    /// above the current one is not treated as being to its left.
    public static func screen(adjacentTo screen: NSScreen, edge: ScreenEdge) -> NSScreen? {
        let origin = screen.frame

        let candidates = NSScreen.screens.filter { other in
            guard other != screen else { return false }
            let frame = other.frame

            switch edge {
            case .left:
                return frame.midX < origin.midX && frame.maxY > origin.minY
                    && frame.minY < origin.maxY
            case .right:
                return frame.midX > origin.midX && frame.maxY > origin.minY
                    && frame.minY < origin.maxY
            case .top:
                return frame.midY > origin.midY && frame.maxX > origin.minX
                    && frame.minX < origin.maxX
            case .bottom:
                return frame.midY < origin.midY && frame.maxX > origin.minX
                    && frame.minX < origin.maxX
            }
        }

        // Nearest neighbour in that direction, measured centre to centre.
        return candidates.min { lhs, rhs in
            let distance: (NSScreen) -> CGFloat = { candidate in
                switch edge {
                case .left, .right: abs(candidate.frame.midX - origin.midX)
                case .top, .bottom: abs(candidate.frame.midY - origin.midY)
                }
            }
            return distance(lhs) < distance(rhs)
        }
    }

    /// Screen `offset` positions along from the one `rect` is on, wrapping at both ends.
    /// Returns `nil` when there is only one display.
    public static func neighbouringScreen(of rect: CGRect, offset: Int) -> NSScreen? {
        let screens = orderedScreens
        guard screens.count > 1,
              let current = screen(containing: rect),
              let index = screens.firstIndex(of: current)
        else { return nil }

        let next = ((index + offset) % screens.count + screens.count) % screens.count
        return screens[next]
    }
}
