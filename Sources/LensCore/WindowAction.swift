import Foundation

/// Every command Lens can perform on a window.
///
/// The first eighteen cases are exact Spectacle 1.2 parity; the rest are additions that ship
/// unbound and can be assigned a shortcut in Settings.
public enum WindowAction: String, CaseIterable, Codable, Sendable {
    // MARK: Halves
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf

    // MARK: Corners
    case upperLeft
    case lowerLeft
    case upperRight
    case lowerRight

    // MARK: Whole screen
    case center
    case fullscreen

    // MARK: Thirds
    case nextThird
    case previousThird
    case firstThird
    case centerThird
    case lastThird
    case firstTwoThirds
    case lastTwoThirds

    // MARK: Sixths
    case topLeftSixth
    case topCenterSixth
    case topRightSixth
    case bottomLeftSixth
    case bottomCenterSixth
    case bottomRightSixth

    // MARK: Relative sizing
    case makeLarger
    case makeSmaller
    case maximizeHeight
    case maximizeWidth
    case almostMaximize

    // MARK: Displays
    case nextDisplay
    case previousDisplay

    // MARK: History
    case undo
    case redo

    /// Human-readable name, used in Settings and the menu bar.
    public var title: String {
        switch self {
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .upperLeft: "Upper Left"
        case .lowerLeft: "Lower Left"
        case .upperRight: "Upper Right"
        case .lowerRight: "Lower Right"
        case .center: "Center"
        case .fullscreen: "Fullscreen"
        case .nextThird: "Next Third"
        case .previousThird: "Previous Third"
        case .firstThird: "First Third"
        case .centerThird: "Center Third"
        case .lastThird: "Last Third"
        case .firstTwoThirds: "First Two Thirds"
        case .lastTwoThirds: "Last Two Thirds"
        case .topLeftSixth: "Top Left Sixth"
        case .topCenterSixth: "Top Center Sixth"
        case .topRightSixth: "Top Right Sixth"
        case .bottomLeftSixth: "Bottom Left Sixth"
        case .bottomCenterSixth: "Bottom Center Sixth"
        case .bottomRightSixth: "Bottom Right Sixth"
        case .makeLarger: "Make Larger"
        case .makeSmaller: "Make Smaller"
        case .maximizeHeight: "Maximize Height"
        case .maximizeWidth: "Maximize Width"
        case .almostMaximize: "Almost Maximize"
        case .nextDisplay: "Next Display"
        case .previousDisplay: "Previous Display"
        case .undo: "Undo"
        case .redo: "Redo"
        }
    }

    /// The eighteen actions Spectacle 1.2 shipped, in the order its preferences window listed
    /// them (left column top-to-bottom, then right column).
    public static let spectacleParity: [WindowAction] = [
        .center, .fullscreen,
        .leftHalf, .rightHalf, .topHalf, .bottomHalf,
        .upperLeft, .lowerLeft, .upperRight, .lowerRight,
        .nextDisplay, .previousDisplay,
        .nextThird, .previousThird,
        .makeLarger, .makeSmaller,
        .undo, .redo,
    ]

    /// Actions added by Lens that Spectacle never had. Unbound by default.
    public static let additions: [WindowAction] = allCases.filter { !spectacleParity.contains($0) }

    /// Moves the window to a different display rather than repositioning it on the current one.
    public var isDisplayAction: Bool {
        self == .nextDisplay || self == .previousDisplay
    }

    /// The screen edge this action pushes the window up against, if any.
    ///
    /// Pressing the shortcut again once the window is already there is what triggers a hop to
    /// the neighbouring display, so only actions that pin a window to one side qualify.
    public var crossingEdge: ScreenEdge? {
        switch self {
        case .leftHalf, .upperLeft, .lowerLeft: .left
        case .rightHalf, .upperRight, .lowerRight: .right
        case .topHalf: .top
        case .bottomHalf: .bottom
        default: nil
        }
    }

    /// The same placement reflected across a display boundary.
    ///
    /// Crossing leftwards should land the window against the *right* edge of the display it
    /// arrives on, so it ends up adjacent to where it came from rather than flying to the far
    /// side of the new screen.
    public var mirroredAcrossEdge: WindowAction? {
        switch self {
        case .leftHalf: .rightHalf
        case .rightHalf: .leftHalf
        case .upperLeft: .upperRight
        case .upperRight: .upperLeft
        case .lowerLeft: .lowerRight
        case .lowerRight: .lowerLeft
        case .topHalf: .bottomHalf
        case .bottomHalf: .topHalf
        default: nil
        }
    }

    /// Replays stored history rather than computing a new frame.
    public var isHistoryAction: Bool {
        self == .undo || self == .redo
    }
}

/// A side of a display, used to work out which neighbour a window should hop to.
public enum ScreenEdge: String, Codable, Sendable, CaseIterable {
    case left
    case right
    case top
    case bottom
}
