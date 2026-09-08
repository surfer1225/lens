import CoreGraphics
import Foundation
import Testing

@testable import LensCore

/// A 14" MacBook Pro's visible frame at default scaling: the reference screen for these tests.
private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

private func frame(
    _ action: WindowAction,
    window: CGRect = CGRect(x: 100, y: 100, width: 400, height: 300),
    on visibleFrame: CGRect = screen,
    cycle: Int = 0,
    gaps: Gaps = .none,
    step: Double = 30
) -> CGRect? {
    RectCalculator.frame(
        for: action,
        window: window,
        visibleFrame: visibleFrame,
        cycleIndex: cycle,
        gaps: gaps,
        resizeStep: step
    )
}

@Suite("Halves and their cycles")
struct HalvesTests {
    @Test("Left half cycles 1/2 -> 1/3 -> 2/3, anchored left")
    func leftHalfCycle() {
        #expect(frame(.leftHalf, cycle: 0) == CGRect(x: 0, y: 0, width: 756, height: 982))
        #expect(frame(.leftHalf, cycle: 1) == CGRect(x: 0, y: 0, width: 504, height: 982))
        #expect(frame(.leftHalf, cycle: 2) == CGRect(x: 0, y: 0, width: 1008, height: 982))
    }

    @Test("Right half cycles anchored right, so its trailing edge never moves")
    func rightHalfCycle() {
        #expect(frame(.rightHalf, cycle: 0) == CGRect(x: 756, y: 0, width: 756, height: 982))
        #expect(frame(.rightHalf, cycle: 1) == CGRect(x: 1008, y: 0, width: 504, height: 982))
        #expect(frame(.rightHalf, cycle: 2) == CGRect(x: 504, y: 0, width: 1008, height: 982))

        for cycle in 0..<3 {
            #expect(frame(.rightHalf, cycle: cycle)?.maxX == 1512)
        }
    }

    @Test("Top and bottom halves split vertically")
    func verticalHalves() {
        #expect(frame(.topHalf) == CGRect(x: 0, y: 491, width: 1512, height: 491))
        #expect(frame(.bottomHalf) == CGRect(x: 0, y: 0, width: 1512, height: 491))
    }

    @Test("Cycle index wraps in both directions rather than trapping")
    func cycleIndexWraps() {
        #expect(frame(.leftHalf, cycle: 3) == frame(.leftHalf, cycle: 0))
        #expect(frame(.leftHalf, cycle: -1) == frame(.leftHalf, cycle: 2))
    }
}

@Suite("Corners")
struct CornerTests {
    @Test("All four corners are a quarter of the screen at cycle 0")
    func cornersAreQuarters() {
        #expect(frame(.upperLeft) == CGRect(x: 0, y: 491, width: 756, height: 491))
        #expect(frame(.lowerLeft) == CGRect(x: 0, y: 0, width: 756, height: 491))
        #expect(frame(.upperRight) == CGRect(x: 756, y: 491, width: 756, height: 491))
        #expect(frame(.lowerRight) == CGRect(x: 756, y: 0, width: 756, height: 491))
    }

    @Test("Corners keep half height while their width cycles")
    func cornersCycleWidthOnly() {
        for cycle in 0..<3 {
            let upper = frame(.upperRight, cycle: cycle)
            #expect(upper?.height == 491)
            #expect(upper?.maxX == 1512)
            #expect(upper?.maxY == 982)
        }
        #expect(frame(.upperRight, cycle: 1)?.width == 504)
        #expect(frame(.upperRight, cycle: 2)?.width == 1008)
    }
}

@Suite("Gaps")
struct GapTests {
    @Test("Outer gap insets the screen; inner gap only shrinks interior edges")
    func leftHalfWithGaps() {
        let gaps = Gaps(outer: 10, inner: 5)
        // Working area is (10, 10, 1492, 962). The half's left/top/bottom edges are flush with
        // it and stay put; only the shared right edge gives up inner/2.
        #expect(frame(.leftHalf, gaps: gaps) == CGRect(x: 10, y: 10, width: 743.5, height: 962))
    }

    @Test("Two adjacent windows end up exactly `inner` points apart")
    func adjacentWindowsAreSeparatedByInner() throws {
        let gaps = Gaps(outer: 10, inner: 5)
        let left = try #require(frame(.leftHalf, gaps: gaps))
        let right = try #require(frame(.rightHalf, gaps: gaps))

        #expect(right.minX - left.maxX == 5)
        #expect(left.minX == 10)
        #expect(right.maxX == 1502)
    }

    @Test("Fullscreen with an outer gap touches nothing but the inset boundary")
    func fullscreenRespectsOuterGap() {
        #expect(frame(.fullscreen, gaps: Gaps(outer: 12, inner: 8))
            == CGRect(x: 12, y: 12, width: 1488, height: 958))
    }

    @Test("An absurd outer gap is clamped instead of inverting the rect")
    func hugeOuterGapDoesNotInvert() throws {
        let tiny = CGRect(x: 0, y: 0, width: 200, height: 150)
        let result = try #require(frame(.leftHalf, on: tiny, gaps: Gaps(outer: 400, inner: 0)))

        #expect(result.width > 0)
        #expect(result.height > 0)
        #expect(tiny.contains(result))
    }
}

@Suite("Size-relative actions")
struct RelativeSizeTests {
    @Test("Center preserves size and centres the window")
    func centerKeepsSize() {
        #expect(frame(.center) == CGRect(x: 556, y: 341, width: 400, height: 300))
    }

    @Test("Center shrinks a window that is larger than the screen")
    func centerClampsOversizedWindow() {
        let huge = CGRect(x: -100, y: -100, width: 2000, height: 1200)
        #expect(frame(.center, window: huge) == CGRect(x: 0, y: 0, width: 1512, height: 982))
    }

    @Test("Make Larger grows by the step on every side, keeping the centre fixed")
    func makeLargerGrowsAroundCentre() {
        #expect(frame(.makeLarger) == CGRect(x: 70, y: 70, width: 460, height: 360))
    }

    @Test("Make Smaller shrinks by the step on every side")
    func makeSmallerShrinksAroundCentre() {
        #expect(frame(.makeSmaller) == CGRect(x: 130, y: 130, width: 340, height: 240))
    }

    @Test("Make Larger clamps to the screen instead of overflowing")
    func makeLargerClampsToScreen() {
        let maximized = CGRect(x: 0, y: 0, width: 1512, height: 982)
        #expect(frame(.makeLarger, window: maximized) == maximized)
    }

    @Test("Repeated Make Smaller stops at the minimum size instead of inverting")
    func makeSmallerHitsFloor() throws {
        var window = CGRect(x: 100, y: 100, width: 400, height: 300)
        for _ in 0..<20 {
            window = try #require(frame(.makeSmaller, window: window))
        }
        #expect(window.width == RectCalculator.minimumSize.width)
        #expect(window.height == RectCalculator.minimumSize.height)
        #expect(screen.contains(window))
    }

    @Test("Maximize Height keeps x and width; Maximize Width keeps y and height")
    func maximizeSingleAxis() {
        let window = CGRect(x: 300, y: 400, width: 500, height: 200)
        #expect(frame(.maximizeHeight, window: window) == CGRect(x: 300, y: 0, width: 500, height: 982))
        #expect(frame(.maximizeWidth, window: window) == CGRect(x: 0, y: 400, width: 1512, height: 200))
    }
}

@Suite("Thirds")
struct ThirdsTests {
    @Test("Next Third walks left -> centre -> right and wraps")
    func nextThirdWalksRight() throws {
        var window = try #require(frame(.firstThird))
        #expect(window == CGRect(x: 0, y: 0, width: 504, height: 982))

        window = try #require(frame(.nextThird, window: window))
        #expect(window == CGRect(x: 504, y: 0, width: 504, height: 982))

        window = try #require(frame(.nextThird, window: window))
        #expect(window == CGRect(x: 1008, y: 0, width: 504, height: 982))

        window = try #require(frame(.nextThird, window: window))
        #expect(window == CGRect(x: 0, y: 0, width: 504, height: 982))
    }

    @Test("Previous Third walks the other way and wraps")
    func previousThirdWalksLeft() throws {
        let leftThird = CGRect(x: 0, y: 0, width: 504, height: 982)
        let result = try #require(frame(.previousThird, window: leftThird))
        #expect(result == CGRect(x: 1008, y: 0, width: 504, height: 982))
    }

    @Test("A window straddling the screen resolves to the third containing its centre")
    func thirdIndexUsesWindowCentre() {
        // A left half's centre sits at x = 378, inside the first third.
        let leftHalf = CGRect(x: 0, y: 0, width: 756, height: 982)
        #expect(RectCalculator.horizontalThirdIndex(of: leftHalf, in: screen) == 0)

        // A right half's centre sits at x = 1134, inside the last third.
        let rightHalf = CGRect(x: 756, y: 0, width: 756, height: 982)
        #expect(RectCalculator.horizontalThirdIndex(of: rightHalf, in: screen) == 2)
    }

    @Test("A window dragged off-screen clamps to a valid third rather than crashing")
    func thirdIndexClampsOffscreenWindows() {
        let farLeft = CGRect(x: -3000, y: 0, width: 400, height: 300)
        let farRight = CGRect(x: 9000, y: 0, width: 400, height: 300)
        #expect(RectCalculator.horizontalThirdIndex(of: farLeft, in: screen) == 0)
        #expect(RectCalculator.horizontalThirdIndex(of: farRight, in: screen) == 2)
    }

    @Test("Sixths tile the screen without overlapping")
    func sixthsTileCleanly() throws {
        let sixths: [WindowAction] = [
            .topLeftSixth, .topCenterSixth, .topRightSixth,
            .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth,
        ]
        let rects = try sixths.map { try #require(frame($0)) }

        for rect in rects {
            #expect(rect.width == 504)
            #expect(rect.height == 491)
        }
        let area = rects.reduce(0) { $0 + $1.width * $1.height }
        #expect(area == screen.width * screen.height)
    }
}

@Suite("Non-geometric actions and other displays")
struct MiscTests {
    @Test("Display and history actions produce no frame; the dispatcher owns them")
    func nonGeometricActionsReturnNil() {
        for action in [WindowAction.nextDisplay, .previousDisplay, .undo, .redo] {
            #expect(frame(action) == nil)
            #expect(RectCalculator.sequence(for: action).isEmpty)
        }
    }

    @Test("Every other action produces a frame inside the screen")
    func allGeometricActionsStayOnScreen() throws {
        for action in WindowAction.allCases
        where !action.isDisplayAction && !action.isHistoryAction {
            for cycle in 0..<3 {
                let result = try #require(frame(action, cycle: cycle), "\(action) cycle \(cycle)")
                #expect(screen.contains(result), "\(action) cycle \(cycle) escaped: \(result)")
            }
        }
    }

    @Test("A display left of and below the primary keeps negative origins intact")
    func negativeOriginDisplay() {
        let secondary = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        #expect(frame(.leftHalf, on: secondary)
            == CGRect(x: -1920, y: -200, width: 960, height: 1080))
        #expect(frame(.lowerRight, on: secondary)
            == CGRect(x: -960, y: -200, width: 960, height: 540))
    }
}

@Suite("Edge crossing")
struct EdgeCrossingTests {
    @Test("Only side-pinning actions can carry a window to another display")
    func crossingEdges() {
        #expect(WindowAction.leftHalf.crossingEdge == .left)
        #expect(WindowAction.rightHalf.crossingEdge == .right)
        #expect(WindowAction.topHalf.crossingEdge == .top)
        #expect(WindowAction.bottomHalf.crossingEdge == .bottom)
        #expect(WindowAction.upperLeft.crossingEdge == .left)
        #expect(WindowAction.lowerRight.crossingEdge == .right)

        // Centred, whole-screen, and relative actions have no edge to cross.
        #expect(WindowAction.center.crossingEdge == nil)
        #expect(WindowAction.fullscreen.crossingEdge == nil)
        #expect(WindowAction.makeLarger.crossingEdge == nil)
        #expect(WindowAction.undo.crossingEdge == nil)
    }

    @Test("Crossing an edge lands the window against the facing side")
    func mirroring() {
        // Going left should arrive on the right of the next display, adjacent to where it left.
        #expect(WindowAction.leftHalf.mirroredAcrossEdge == .rightHalf)
        #expect(WindowAction.upperLeft.mirroredAcrossEdge == .upperRight)
        #expect(WindowAction.lowerLeft.mirroredAcrossEdge == .lowerRight)
        #expect(WindowAction.topHalf.mirroredAcrossEdge == .bottomHalf)
    }

    @Test("Mirroring is symmetric, and preserves the vertical half of a corner")
    func mirroringIsSymmetric() {
        for action in WindowAction.allCases {
            guard let mirrored = action.mirroredAcrossEdge else { continue }
            #expect(mirrored.mirroredAcrossEdge == action, "\(action) did not round-trip")
            #expect(mirrored.crossingEdge != action.crossingEdge, "\(action) kept its edge")
        }
    }

    @Test("Every action that can cross has a mirror, and vice versa")
    func crossingAndMirroringAgree() {
        for action in WindowAction.allCases {
            #expect(
                (action.crossingEdge == nil) == (action.mirroredAcrossEdge == nil),
                "\(action) has one of crossingEdge/mirroredAcrossEdge but not the other"
            )
        }
    }
}

@Suite("Settings")
struct SettingsTests {
    @Test("Settings survive a JSON round trip")
    func jsonRoundTrip() throws {
        let original = Settings(
            gaps: Gaps(outer: 8, inner: 4),
            subsequentExecution: .cycleSizes,
            resizeStep: 45,
            unfullscreenBeforeMoving: false,
            stageManagerInset: 72,
            excludedBundleIDs: ["com.apple.systempreferences"],
            undoDepth: 10
        )
        #expect(try Settings.from(jsonData: original.jsonData()) == original)
    }

    @Test("Repeated presses cross displays by default, matching Spectacle")
    func defaultIsEdgeCrossing() {
        #expect(Settings.default.subsequentExecution == .moveToAdjacentDisplay)
    }

    @Test("Config saved by an older build still decodes, keeping the fields it does have")
    func lenientDecoding() throws {
        // No subsequentExecution key — as written before the setting existed.
        let legacy = #"{"gaps":{"outer":12,"inner":6},"resizeStep":40}"#
        let decoded = try Settings.from(jsonData: Data(legacy.utf8))

        #expect(decoded.gaps == Gaps(outer: 12, inner: 6))
        #expect(decoded.resizeStep == 40)
        #expect(decoded.subsequentExecution == Settings.default.subsequentExecution)
        #expect(decoded.undoDepth == Settings.default.undoDepth)
    }

    @Test("An unrecognised enum value falls back rather than discarding the whole config")
    func unknownEnumValueFallsBack() throws {
        let future = #"{"gaps":{"outer":5,"inner":0},"subsequentExecution":"teleport"}"#
        let decoded = try Settings.from(jsonData: Data(future.utf8))

        #expect(decoded.gaps == Gaps(outer: 5, inner: 0))
        #expect(decoded.subsequentExecution == Settings.default.subsequentExecution)
    }

    @Test("Exclusion matching handles a missing bundle identifier")
    func exclusionMatching() {
        let settings = Settings(excludedBundleIDs: ["com.apple.finder"])
        #expect(settings.excludes(bundleID: "com.apple.finder"))
        #expect(!settings.excludes(bundleID: "com.apple.Safari"))
        #expect(!settings.excludes(bundleID: nil))
    }
}
