import CoreGraphics

/// A rectangle expressed as fractions of the screen's working area, using Cocoa orientation
/// (origin bottom-left, y grows upward).
///
/// Expressing layouts this way keeps `RectCalculator` free of display dimensions, so the same
/// table of constants is correct on every screen size.
public struct UnitRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(_ x: Double, _ y: Double, _ width: Double, _ height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Scales this unit rect onto a concrete working area.
    public func resolved(in work: CGRect) -> CGRect {
        CGRect(
            x: work.minX + CGFloat(x) * work.width,
            y: work.minY + CGFloat(y) * work.height,
            width: CGFloat(width) * work.width,
            height: CGFloat(height) * work.height
        )
    }

    // Common fractions, named so the layout tables below read like the UI labels.
    public static let full = UnitRect(0, 0, 1, 1)

    public static let leftHalf = UnitRect(0, 0, 1.0 / 2, 1)
    public static let rightHalf = UnitRect(1.0 / 2, 0, 1.0 / 2, 1)
    public static let topHalf = UnitRect(0, 1.0 / 2, 1, 1.0 / 2)
    public static let bottomHalf = UnitRect(0, 0, 1, 1.0 / 2)

    public static let leftThird = UnitRect(0, 0, 1.0 / 3, 1)
    public static let rightThird = UnitRect(2.0 / 3, 0, 1.0 / 3, 1)
    public static let leftTwoThirds = UnitRect(0, 0, 2.0 / 3, 1)
    public static let rightTwoThirds = UnitRect(1.0 / 3, 0, 2.0 / 3, 1)
    public static let centerThird = UnitRect(1.0 / 3, 0, 1.0 / 3, 1)

    public static let topThird = UnitRect(0, 2.0 / 3, 1, 1.0 / 3)
    public static let bottomThird = UnitRect(0, 0, 1, 1.0 / 3)
    public static let topTwoThirds = UnitRect(0, 1.0 / 3, 1, 2.0 / 3)
    public static let bottomTwoThirds = UnitRect(0, 0, 1, 2.0 / 3)

    public static let almostFull = UnitRect(0.05, 0.05, 0.9, 0.9)

    /// Horizontal third `index` (0-based), full height.
    public static func horizontalThird(_ index: Int) -> UnitRect {
        UnitRect(Double(index) / 3, 0, 1.0 / 3, 1)
    }
}
