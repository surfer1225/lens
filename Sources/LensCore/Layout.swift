import CoreGraphics
import Foundation

/// One display, described in terms stable enough to recognise the same physical setup again.
///
/// Resolution and arrangement are included because the same monitor plugged into a different
/// position is, for layout purposes, a different setup.
public struct ScreenDescriptor: Hashable, Codable, Sendable {
    public let name: String
    public let width: Int
    public let height: Int
    public let originX: Int
    public let originY: Int

    public init(name: String, frame: CGRect) {
        self.name = name
        self.width = Int(frame.width.rounded())
        self.height = Int(frame.height.rounded())
        self.originX = Int(frame.origin.x.rounded())
        self.originY = Int(frame.origin.y.rounded())
    }

    /// Compact, stable textual form. Order-independent by construction — see `DisplayFingerprint`.
    var token: String { "\(name)@\(width)x\(height)+\(originX)+\(originY)" }
}

/// Identifies a whole display arrangement, so a layout can be remembered per setup.
///
/// "Laptop alone", "laptop + monitor at the office", and "laptop + two monitors at home" each get
/// their own fingerprint, and each remembers where you like your windows.
public struct DisplayFingerprint: Hashable, Codable, Sendable {
    public let value: String

    public init(value: String) {
        self.value = value
    }

    public init(screens: [ScreenDescriptor]) {
        // Sorted so that the order macOS happens to enumerate displays in cannot change the
        // fingerprint of a physically identical setup.
        self.value = screens.map(\.token).sorted().joined(separator: "|")
    }

    public var isEmpty: Bool { value.isEmpty }
}

/// Where one window was, recorded in terms that can find it again after a relaunch.
public struct WindowSnapshot: Codable, Equatable, Sendable {
    public let bundleID: String
    /// Window title at capture time. Often the best identifier, but documents get renamed and
    /// plenty of windows share a title, so it is a hint rather than a key.
    public let title: String
    /// Position among that application's windows at capture time, used when titles cannot
    /// disambiguate.
    public let index: Int
    public let frame: CGRect

    public init(bundleID: String, title: String, index: Int, frame: CGRect) {
        self.bundleID = bundleID
        self.title = title
        self.index = index
        self.frame = frame
    }
}

/// A remembered arrangement for one display configuration.
public struct Layout: Codable, Equatable, Sendable {
    public let fingerprint: DisplayFingerprint
    public let snapshots: [WindowSnapshot]
    public let capturedAt: Date

    public init(fingerprint: DisplayFingerprint, snapshots: [WindowSnapshot], capturedAt: Date = Date()) {
        self.fingerprint = fingerprint
        self.snapshots = snapshots
        self.capturedAt = capturedAt
    }

    public var isEmpty: Bool { snapshots.isEmpty }
}

/// Every layout Lens has learned, keyed by display configuration.
///
/// Deliberately a plain `Codable` value: it round-trips to JSON, which keeps it inspectable and
/// syncable rather than trapped in an opaque preferences blob.
public struct LayoutLibrary: Codable, Equatable, Sendable {
    public private(set) var layouts: [String: Layout]

    public init(layouts: [String: Layout] = [:]) {
        self.layouts = layouts
    }

    public func layout(for fingerprint: DisplayFingerprint) -> Layout? {
        layouts[fingerprint.value]
    }

    /// The most display setups remembered. Beyond it, the one used longest ago is forgotten,
    /// so layouts from a hotel monitor two years ago don't linger.
    public static let maximumSetups = 20

    public mutating func store(_ layout: Layout) {
        guard !layout.isEmpty else { return }
        layouts[layout.fingerprint.value] = layout
        while layouts.count > Self.maximumSetups,
              let oldest = layouts.min(by: { $0.value.capturedAt < $1.value.capturedAt })?.key {
            layouts.removeValue(forKey: oldest)
        }
    }

    /// The same layouts with every window title passed through `transform` (e.g. replaced by a
    /// digest), keeping everything else.
    public func mappingTitles(_ transform: (String) -> String) -> LayoutLibrary {
        LayoutLibrary(layouts: layouts.mapValues { layout in
            Layout(
                fingerprint: layout.fingerprint,
                snapshots: layout.snapshots.map {
                    WindowSnapshot(bundleID: $0.bundleID, title: transform($0.title), index: $0.index, frame: $0.frame)
                },
                capturedAt: layout.capturedAt)
        })
    }

    public mutating func forget(_ fingerprint: DisplayFingerprint) {
        layouts.removeValue(forKey: fingerprint.value)
    }

    public mutating func removeAll() {
        layouts.removeAll()
    }

    public var count: Int { layouts.count }
}
