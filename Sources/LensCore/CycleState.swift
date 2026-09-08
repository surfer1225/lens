import CoreGraphics

/// Stable-enough identity for a window across key presses.
///
/// Normally wraps a `CGWindowID`; when that cannot be obtained it wraps a hash of the owning
/// process and the window title (see `LensAX.AXWindow.identifier`).
public struct WindowID: Hashable, Sendable {
    public let raw: UInt64
    /// False when this identity came from the title-hash fallback, which is not reliable enough
    /// to drive cycling.
    public let isExact: Bool

    public init(raw: UInt64, isExact: Bool = true) {
        self.raw = raw
        self.isExact = isExact
    }
}

public struct CycleKey: Hashable, Sendable {
    public let window: WindowID
    public let action: WindowAction

    public init(window: WindowID, action: WindowAction) {
        self.window = window
        self.action = action
    }
}

/// Drives "press the same shortcut again to cycle through sizes".
///
/// Deliberately timer-free. Rather than expiring after N seconds, a repeat only counts if the
/// window is still sitting exactly where we last put it — so a cycle survives a long pause, but
/// any manual resize or a different window in between resets it. That is more predictable than a
/// timeout, and it needs no clock.
public struct CycleState: Sendable {
    /// How far a window may have drifted from where we put it and still count as unmoved.
    /// Apps that quantise their size (Terminal) land a few points off what we asked for.
    public var tolerance: CGFloat

    private var lastKey: CycleKey?
    private var lastAppliedFrame: CGRect = .zero
    private var lastIndex: Int = 0

    public init(tolerance: CGFloat = 8) {
        self.tolerance = tolerance
    }

    /// Whether this press repeats the last one on a window we have not lost track of.
    ///
    /// True only if the same shortcut was last applied to the same window *and* the window is
    /// still sitting where we put it.
    public func isRepeat(of key: CycleKey, currentFrame: CGRect) -> Bool {
        guard key.window.isExact, let lastKey, lastKey == key else { return false }
        return currentFrame.isNear(lastAppliedFrame, tolerance: tolerance)
    }

    /// The step of the cycle this press should apply.
    public func index(
        for key: CycleKey,
        currentFrame: CGRect,
        cycleLength: Int,
        cyclingEnabled: Bool
    ) -> Int {
        guard cyclingEnabled, cycleLength > 1 else { return 0 }
        guard isRepeat(of: key, currentFrame: currentFrame) else { return 0 }

        return (lastIndex + 1) % cycleLength
    }

    /// Records what we actually applied, so the next press can tell whether the user has since
    /// moved the window themselves.
    public mutating func record(key: CycleKey, appliedFrame: CGRect, index: Int) {
        lastKey = key
        lastAppliedFrame = appliedFrame
        lastIndex = index
    }

    /// Forgets the current chain, so the next press starts from step 0.
    public mutating func reset() {
        lastKey = nil
        lastAppliedFrame = .zero
        lastIndex = 0
    }
}

extension CGRect {
    /// True when every edge is within `tolerance` points of `other`.
    public func isNear(_ other: CGRect, tolerance: CGFloat) -> Bool {
        abs(minX - other.minX) <= tolerance
            && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance
            && abs(height - other.height) <= tolerance
    }
}
