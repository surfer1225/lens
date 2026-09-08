import CoreGraphics

/// Padding applied when placing a window.
public struct Gaps: Equatable, Codable, Sendable {
    /// Space left between the window and the edge of the screen's visible frame.
    public var outer: Double
    /// Total space left between two windows that sit side by side. Each of the two windows
    /// gives up half of this on the shared edge.
    public var inner: Double

    public init(outer: Double = 0, inner: Double = 0) {
        self.outer = outer
        self.inner = inner
    }

    public static let none = Gaps()

    /// The area a window may occupy on `visibleFrame` once the outer gap is taken out.
    ///
    /// Guards against a gap large enough to invert the rect on a small display.
    public func workingFrame(in visibleFrame: CGRect) -> CGRect {
        let maxInset = min(visibleFrame.width, visibleFrame.height) / 2 - 1
        let inset = max(0, min(CGFloat(outer), maxInset))
        return visibleFrame.insetBy(dx: inset, dy: inset)
    }

    /// Shrinks the edges of `rect` that do not sit flush against `work`, so that two adjacent
    /// windows end up separated by exactly `inner` points.
    public func applyingInnerGap(to rect: CGRect, in work: CGRect) -> CGRect {
        guard inner > 0 else { return rect }

        let half = CGFloat(inner) / 2
        let epsilon: CGFloat = 0.5

        var minX = rect.minX, maxX = rect.maxX
        var minY = rect.minY, maxY = rect.maxY

        if minX > work.minX + epsilon { minX += half }
        if maxX < work.maxX - epsilon { maxX -= half }
        if minY > work.minY + epsilon { minY += half }
        if maxY < work.maxY - epsilon { maxY -= half }

        guard maxX > minX, maxY > minY else { return rect }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
