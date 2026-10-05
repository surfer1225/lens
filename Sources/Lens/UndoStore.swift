import CoreGraphics
import LensCore

/// Per-window frame history.
///
/// Spectacle kept a single global last action; keying by window means undoing in one app does not
/// consume the undo you wanted in another.
struct UndoStore {
    var depth: Int = 20

    private var undoStacks: [WindowID: [CGRect]] = [:]
    private var redoStacks: [WindowID: [CGRect]] = [:]

    /// Call immediately before moving a window, with the frame it is about to leave.
    mutating func record(_ frame: CGRect, for window: WindowID) {
        var stack = undoStacks[window, default: []]
        stack.append(frame)
        let depth = max(0, self.depth)
        if stack.count > depth {
            stack.removeFirst(stack.count - depth)
        }
        undoStacks[window] = stack

        // A fresh action invalidates anything that was undone before it.
        redoStacks[window] = nil
    }

    /// The frame to restore, having pushed `current` onto the redo stack.
    mutating func undo(from current: CGRect, for window: WindowID) -> CGRect? {
        guard var stack = undoStacks[window], let previous = stack.popLast() else { return nil }
        undoStacks[window] = stack
        redoStacks[window, default: []].append(current)
        return previous
    }

    /// The frame to re-apply, having pushed `current` back onto the undo stack.
    mutating func redo(from current: CGRect, for window: WindowID) -> CGRect? {
        guard var stack = redoStacks[window], let next = stack.popLast() else { return nil }
        redoStacks[window] = stack
        undoStacks[window, default: []].append(current)
        return next
    }

    /// Drops history for windows that no longer exist, so a long-running session does not grow
    /// a stack for every window ever touched.
    mutating func prune(keeping live: Set<WindowID>) {
        undoStacks = undoStacks.filter { live.contains($0.key) }
        redoStacks = redoStacks.filter { live.contains($0.key) }
    }
}
