import AppKit
import ApplicationServices
import LensAX
import LensCore

/// Turns a hotkey press into a moved window.
///
/// The one place that knows the whole sequence: find the focused window, decide the target frame,
/// snapshot the old one for undo, then apply it while working around the app's quirks.
@MainActor
final class ActionDispatcher {
    var settings: Settings {
        didSet { undoStore.depth = settings.undoDepth }
    }

    private var cycleState = CycleState()
    private var undoStore = UndoStore()

    init(settings: Settings) {
        self.settings = settings
        self.undoStore.depth = settings.undoDepth
    }

    func perform(_ action: WindowAction) {
        guard AXIsProcessTrusted() else {
            NSSound.beep()
            return
        }
        guard let app = AXApplication.frontmost,
              !settings.excludes(bundleID: app.bundleIdentifier),
              let window = app.focusedWindow
        else {
            NSSound.beep()
            return
        }

        app.withEnhancedUserInterfaceDisabled {
            apply(action, to: window)
        }
    }

    // MARK: - Dispatch

    private func apply(_ action: WindowAction, to window: AXWindow) {
        // Nothing lands on a fullscreen window until it leaves fullscreen.
        if window.isFullscreen {
            guard settings.unfullscreenBeforeMoving, window.exitFullscreen() else {
                NSSound.beep()
                return
            }
            // The transition is animated; the window reports its old frame until it finishes.
            waitForFullscreenExit(of: window)
        }

        guard window.isArrangeable, let current = window.frame else {
            NSSound.beep()
            return
        }

        let identifier = window.identifier

        switch action {
        case .undo:
            guard let restored = undoStore.undo(from: current, for: identifier) else {
                NSSound.beep()
                return
            }
            move(window, to: restored, recordUndo: false)
            cycleState.reset()

        case .redo:
            guard let restored = undoStore.redo(from: current, for: identifier) else {
                NSSound.beep()
                return
            }
            move(window, to: restored, recordUndo: false)
            cycleState.reset()

        case .nextDisplay, .previousDisplay:
            moveToNeighbouringDisplay(
                window,
                current: current,
                offset: action == .nextDisplay ? 1 : -1
            )

        default:
            applyGeometry(action, to: window, current: current, identifier: identifier)
        }
    }

    private func applyGeometry(
        _ action: WindowAction,
        to window: AXWindow,
        current: CGRect,
        identifier: WindowID
    ) {
        guard let screen = ScreenDetector.screen(containing: current) else {
            NSSound.beep()
            return
        }

        let key = CycleKey(window: identifier, action: action)

        // Spectacle's behaviour: once a window is already pinned to a side, pressing the same
        // shortcut again carries it to the display beyond that edge rather than resizing it.
        if settings.subsequentExecution == .moveToAdjacentDisplay,
           cycleState.isRepeat(of: key, currentFrame: current),
           let edge = action.crossingEdge,
           let mirrored = action.mirroredAcrossEdge,
           let destination = ScreenDetector.screen(adjacentTo: screen, edge: edge) {
            crossTo(destination, window: window, action: mirrored, identifier: identifier)
            return
        }

        let usable = ScreenDetector.usableFrame(of: screen, settings: settings)
        let cycleLength = RectCalculator.sequence(for: action).count
        // With edge-crossing selected, a repeat on a display with no neighbour that way falls
        // through to here and cycles sizes instead of doing nothing.
        let index = cycleState.index(
            for: key,
            currentFrame: current,
            cycleLength: cycleLength,
            cyclingEnabled: settings.subsequentExecution != .repeatSameFrame
        )

        guard let target = RectCalculator.frame(
            for: action,
            window: current,
            visibleFrame: usable,
            cycleIndex: index,
            gaps: settings.gaps,
            resizeStep: settings.resizeStep
        ) else {
            NSSound.beep()
            return
        }

        // Record the frame we asked for rather than the one the window settled on, so that a
        // window whose app quantises its size still matches on the next press.
        let applied = move(window, to: target, in: usable, recordUndo: true)
        cycleState.record(key: key, appliedFrame: applied ?? target, index: index)
    }

    /// Places the window against the facing edge of `destination`.
    ///
    /// Records the mirrored action in the cycle state, so pressing the shortcut a third time
    /// keeps travelling in the same direction rather than bouncing back.
    private func crossTo(
        _ destination: NSScreen,
        window: AXWindow,
        action mirrored: WindowAction,
        identifier: WindowID
    ) {
        let usable = ScreenDetector.usableFrame(of: destination, settings: settings)

        guard let target = RectCalculator.frame(
            for: mirrored,
            window: window.frame ?? usable,
            visibleFrame: usable,
            cycleIndex: 0,
            gaps: settings.gaps,
            resizeStep: settings.resizeStep
        ) else {
            NSSound.beep()
            return
        }

        let applied = move(window, to: target, in: usable, recordUndo: true)
        cycleState.record(
            key: CycleKey(window: identifier, action: mirrored),
            appliedFrame: applied ?? target,
            index: 0
        )
    }

    private func moveToNeighbouringDisplay(_ window: AXWindow, current: CGRect, offset: Int) {
        guard let source = ScreenDetector.screen(containing: current),
              let destination = ScreenDetector.neighbouringScreen(of: current, offset: offset)
        else {
            NSSound.beep()
            return
        }

        let from = ScreenDetector.usableFrame(of: source, settings: settings)
        let to = ScreenDetector.usableFrame(of: destination, settings: settings)
        guard from.width > 0, from.height > 0 else { return }

        // Keep the window's proportions relative to the screen rather than its absolute size, so
        // a half-width window stays half-width on a display of a different resolution.
        let target = CGRect(
            x: to.minX + (current.minX - from.minX) / from.width * to.width,
            y: to.minY + (current.minY - from.minY) / from.height * to.height,
            width: current.width / from.width * to.width,
            height: current.height / from.height * to.height
        )

        move(window, to: RectCalculator.clamp(target, to: to), in: to, recordUndo: true)
        // The window is on a different screen now; any cycle in progress no longer applies.
        cycleState.reset()
    }

    // MARK: - Applying

    @discardableResult
    private func move(
        _ window: AXWindow,
        to target: CGRect,
        in usable: CGRect? = nil,
        recordUndo: Bool
    ) -> CGRect? {
        guard let current = window.frame else { return nil }

        if recordUndo {
            undoStore.record(current, for: window.identifier)
        }

        var bounds = target
        if let usable {
            bounds = usable
        } else if let screen = ScreenDetector.screen(containing: target) {
            bounds = ScreenDetector.usableFrame(of: screen, settings: settings)
        }

        return window.setFrame(target, constrainedTo: bounds)
    }

    /// Blocks briefly while a fullscreen exit animation completes.
    ///
    /// Setting a frame mid-animation is ignored. Polling the reported frame is crude, but there
    /// is no completion callback for the transition, and the alternative — a fixed sleep long
    /// enough to always work — is slower in the common case.
    private func waitForFullscreenExit(of window: AXWindow, timeout: TimeInterval = 1.0) {
        let deadline = Date().addingTimeInterval(timeout)
        while window.isFullscreen, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }
}
