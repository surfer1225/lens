import CoreGraphics

/// How a single step of an action positions the window.
///
/// Most actions are a fixed fraction of the screen (`unit`); a few depend on where the window
/// currently is, and get their own case.
public enum FrameSpec: Equatable, Sendable {
    /// A fixed fraction of the working area.
    case unit(UnitRect)
    /// Keep the window's current size, centre it on the screen.
    case center
    /// Keep the window's x and width, span the full height.
    case maximizeHeight
    /// Keep the window's y and height, span the full width.
    case maximizeWidth
    /// Grow (`+1`) or shrink (`-1`) around the window's centre by the configured step.
    case resize(direction: Int)
    /// Move the window `offset` horizontal thirds along from whichever third it currently sits in.
    case relativeThird(offset: Int)
}

/// Turns an action plus the current geometry into the frame a window should end up at.
///
/// Everything here is pure: it takes `CGRect`s in Cocoa orientation (origin bottom-left) and
/// returns one, with no reference to `NSScreen`, `AXUIElement`, or user defaults. Coordinate
/// conversion happens at the `LensAX` boundary.
public enum RectCalculator {
    /// No action may shrink a window below this, regardless of gaps or repeated shrink presses.
    public static let minimumSize = CGSize(width: 120, height: 80)

    /// The sequence a repeated key press walks through.
    ///
    /// Index 0 is what a single press does, so a caller that has cycling disabled can simply
    /// always pass `cycleIndex: 0` and get exact Spectacle behaviour.
    public static func sequence(for action: WindowAction) -> [FrameSpec] {
        switch action {
        // Halves cycle 1/2 -> 1/3 -> 2/3, anchored to the side they are named after.
        case .leftHalf:
            [.unit(.leftHalf), .unit(.leftThird), .unit(.leftTwoThirds)]
        case .rightHalf:
            [.unit(.rightHalf), .unit(.rightThird), .unit(.rightTwoThirds)]
        case .topHalf:
            [.unit(.topHalf), .unit(.topThird), .unit(.topTwoThirds)]
        case .bottomHalf:
            [.unit(.bottomHalf), .unit(.bottomThird), .unit(.bottomTwoThirds)]

        // Corners keep their half-height and cycle their width the same way.
        case .upperLeft:
            [.unit(UnitRect(0, 0.5, 1.0 / 2, 1.0 / 2)),
             .unit(UnitRect(0, 0.5, 1.0 / 3, 1.0 / 2)),
             .unit(UnitRect(0, 0.5, 2.0 / 3, 1.0 / 2))]
        case .lowerLeft:
            [.unit(UnitRect(0, 0, 1.0 / 2, 1.0 / 2)),
             .unit(UnitRect(0, 0, 1.0 / 3, 1.0 / 2)),
             .unit(UnitRect(0, 0, 2.0 / 3, 1.0 / 2))]
        case .upperRight:
            [.unit(UnitRect(1.0 / 2, 0.5, 1.0 / 2, 1.0 / 2)),
             .unit(UnitRect(2.0 / 3, 0.5, 1.0 / 3, 1.0 / 2)),
             .unit(UnitRect(1.0 / 3, 0.5, 2.0 / 3, 1.0 / 2))]
        case .lowerRight:
            [.unit(UnitRect(1.0 / 2, 0, 1.0 / 2, 1.0 / 2)),
             .unit(UnitRect(2.0 / 3, 0, 1.0 / 3, 1.0 / 2)),
             .unit(UnitRect(1.0 / 3, 0, 2.0 / 3, 1.0 / 2))]

        // Spectacle's Fullscreen and Center do not cycle, and neither do ours.
        case .fullscreen:
            [.unit(.full)]
        case .center:
            [.center]
        case .almostMaximize:
            [.unit(.almostFull)]
        case .maximizeHeight:
            [.maximizeHeight]
        case .maximizeWidth:
            [.maximizeWidth]

        case .nextThird:
            [.relativeThird(offset: 1)]
        case .previousThird:
            [.relativeThird(offset: -1)]

        case .firstThird:
            [.unit(.leftThird)]
        case .centerThird:
            [.unit(.centerThird)]
        case .lastThird:
            [.unit(.rightThird)]
        case .firstTwoThirds:
            [.unit(.leftTwoThirds)]
        case .lastTwoThirds:
            [.unit(.rightTwoThirds)]

        case .topLeftSixth:
            [.unit(UnitRect(0, 0.5, 1.0 / 3, 1.0 / 2))]
        case .topCenterSixth:
            [.unit(UnitRect(1.0 / 3, 0.5, 1.0 / 3, 1.0 / 2))]
        case .topRightSixth:
            [.unit(UnitRect(2.0 / 3, 0.5, 1.0 / 3, 1.0 / 2))]
        case .bottomLeftSixth:
            [.unit(UnitRect(0, 0, 1.0 / 3, 1.0 / 2))]
        case .bottomCenterSixth:
            [.unit(UnitRect(1.0 / 3, 0, 1.0 / 3, 1.0 / 2))]
        case .bottomRightSixth:
            [.unit(UnitRect(2.0 / 3, 0, 1.0 / 3, 1.0 / 2))]

        case .makeLarger:
            [.resize(direction: 1)]
        case .makeSmaller:
            [.resize(direction: -1)]

        // Handled by the dispatcher, not by geometry.
        case .nextDisplay, .previousDisplay, .undo, .redo:
            []
        }
    }

    /// The frame `window` should be moved to, or `nil` if this action is not a geometric one.
    ///
    /// - Parameters:
    ///   - window: current window frame, Cocoa orientation.
    ///   - visibleFrame: the target screen's visible frame, Cocoa orientation, already adjusted
    ///     for the menu bar, Dock, and Stage Manager by the caller.
    ///   - cycleIndex: which step of `sequence(for:)` to apply. Out-of-range values wrap.
    public static func frame(
        for action: WindowAction,
        window: CGRect,
        visibleFrame: CGRect,
        cycleIndex: Int = 0,
        gaps: Gaps = .none,
        resizeStep: Double = 30
    ) -> CGRect? {
        let specs = sequence(for: action)
        guard !specs.isEmpty else { return nil }

        let spec = specs[((cycleIndex % specs.count) + specs.count) % specs.count]
        let work = gaps.workingFrame(in: visibleFrame)
        guard work.width > 0, work.height > 0 else { return nil }

        return resolve(spec, window: window, work: work, gaps: gaps, resizeStep: resizeStep)
    }

    // MARK: - Spec resolution

    private static func resolve(
        _ spec: FrameSpec,
        window: CGRect,
        work: CGRect,
        gaps: Gaps,
        resizeStep: Double
    ) -> CGRect {
        switch spec {
        case .unit(let unit):
            return clamp(gaps.applyingInnerGap(to: unit.resolved(in: work), in: work), to: work)

        case .center:
            let size = CGSize(
                width: min(window.width, work.width),
                height: min(window.height, work.height)
            )
            return clamp(
                CGRect(
                    x: work.midX - size.width / 2,
                    y: work.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                ),
                to: work
            )

        case .maximizeHeight:
            let width = min(window.width, work.width)
            return clamp(
                CGRect(x: window.minX, y: work.minY, width: width, height: work.height),
                to: work
            )

        case .maximizeWidth:
            let height = min(window.height, work.height)
            return clamp(
                CGRect(x: work.minX, y: window.minY, width: work.width, height: height),
                to: work
            )

        case .resize(let direction):
            let delta = CGFloat(resizeStep) * CGFloat(direction)
            let size = CGSize(
                width: min(window.width + 2 * delta, work.width),
                height: min(window.height + 2 * delta, work.height)
            )
            return clamp(
                CGRect(
                    x: window.midX - size.width / 2,
                    y: window.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                ),
                to: work
            )

        case .relativeThird(let offset):
            let current = horizontalThirdIndex(of: window, in: work)
            let next = ((current + offset) % 3 + 3) % 3
            let unit = UnitRect.horizontalThird(next)
            return clamp(gaps.applyingInnerGap(to: unit.resolved(in: work), in: work), to: work)
        }
    }

    /// Which horizontal third of `work` the window's centre currently falls in.
    ///
    /// A window off the left or right edge clamps to the nearest third rather than producing an
    /// out-of-range index.
    public static func horizontalThirdIndex(of window: CGRect, in work: CGRect) -> Int {
        guard work.width > 0 else { return 0 }
        let fraction = (window.midX - work.minX) / work.width
        return min(2, max(0, Int(fraction * 3)))
    }

    /// Forces `rect` to sit inside `work` at no smaller than `minimumSize`.
    public static func clamp(_ rect: CGRect, to work: CGRect) -> CGRect {
        var result = rect

        result.size.width = min(max(result.width, min(minimumSize.width, work.width)), work.width)
        result.size.height = min(max(result.height, min(minimumSize.height, work.height)), work.height)

        result.origin.x = min(max(result.minX, work.minX), work.maxX - result.width)
        result.origin.y = min(max(result.minY, work.minY), work.maxY - result.height)

        return result
    }
}
