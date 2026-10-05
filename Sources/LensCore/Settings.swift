import Foundation

/// Everything the user can configure apart from the shortcuts themselves, which the
/// KeyboardShortcuts package stores separately.
///
/// `Codable` so Settings can export and import the whole configuration as JSON.
/// What pressing an already-satisfied shortcut a second time does.
public enum SubsequentExecution: String, Codable, Sendable, CaseIterable {
    /// Walk the size cycle: 1/2 -> 1/3 -> 2/3.
    case cycleSizes
    /// Carry the window to the neighbouring display, landing it against the facing edge — what
    /// Spectacle did. Falls back to `cycleSizes` when there is no display that way.
    case moveToAdjacentDisplay
    /// Re-apply the same frame every time.
    case repeatSameFrame

    public var title: String {
        switch self {
        case .cycleSizes: "Cycle through sizes (½ → ⅓ → ⅔)"
        case .moveToAdjacentDisplay: "Move to the next display"
        case .repeatSameFrame: "Do nothing new"
        }
    }
}

public struct Settings: Codable, Equatable, Sendable {
    public var gaps: Gaps

    /// What a repeated press of the same shortcut does.
    public var subsequentExecution: SubsequentExecution

    /// Points added to (or removed from) each side by Make Larger / Make Smaller.
    public var resizeStep: Double

    /// Take a window out of native fullscreen before repositioning it. Without this, macOS
    /// silently ignores position and size changes on fullscreen windows.
    public var unfullscreenBeforeMoving: Bool

    /// Stage Manager's strip is not excluded from `NSScreen.visibleFrame`, so reserve space for
    /// it manually when it is enabled. Zero disables the adjustment.
    public var stageManagerInset: Double

    /// Bundle identifiers Lens will refuse to touch.
    public var excludedBundleIDs: [String]

    /// How many frames of history to keep per window for undo/redo.
    public var undoDepth: Int

    /// Remember where windows sit in each display arrangement, and put them back on returning to
    /// one. Only ever acts on a setup it has seen before.
    public var automaticLayoutRestore: Bool

    public init(
        gaps: Gaps = .none,
        subsequentExecution: SubsequentExecution = .moveToAdjacentDisplay,
        resizeStep: Double = 30,
        unfullscreenBeforeMoving: Bool = true,
        stageManagerInset: Double = 64,
        excludedBundleIDs: [String] = [],
        undoDepth: Int = 20,
        automaticLayoutRestore: Bool = true
    ) {
        self.gaps = gaps
        self.subsequentExecution = subsequentExecution
        self.resizeStep = resizeStep
        self.unfullscreenBeforeMoving = unfullscreenBeforeMoving
        self.stageManagerInset = stageManagerInset
        self.excludedBundleIDs = excludedBundleIDs
        self.undoDepth = undoDepth
        self.automaticLayoutRestore = automaticLayoutRestore
    }

    public static let `default` = Settings()

    /// Decodes leniently: any field the stored JSON lacks falls back to its default.
    ///
    /// Without this, adding or renaming a setting makes the whole saved configuration fail to
    /// decode, silently discarding the user's gaps and exclusion list along with it.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Settings()

        func value<T: Decodable>(_ key: CodingKeys, _ defaultValue: T) -> T {
            ((try? container.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? defaultValue
        }

        self.gaps = value(.gaps, fallback.gaps)
        self.subsequentExecution = value(.subsequentExecution, fallback.subsequentExecution)
        self.resizeStep = value(.resizeStep, fallback.resizeStep)
        self.unfullscreenBeforeMoving = value(
            .unfullscreenBeforeMoving, fallback.unfullscreenBeforeMoving
        )
        self.stageManagerInset = value(.stageManagerInset, fallback.stageManagerInset)
        self.excludedBundleIDs = value(.excludedBundleIDs, fallback.excludedBundleIDs)
        self.undoDepth = value(.undoDepth, fallback.undoDepth)
        self.automaticLayoutRestore = value(.automaticLayoutRestore, fallback.automaticLayoutRestore)
        clampToSupportedRanges()
    }

    /// Keeps every number in the range the Settings window offers. Imported files and stored
    /// preferences can hold anything, and a negative undo depth or an astronomical step would
    /// crash Lens on every use.
    public mutating func clampToSupportedRanges() {
        func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
            value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
        }
        let defaults = Settings()
        gaps.outer = clamp(gaps.outer, 0...40, defaults.gaps.outer)
        gaps.inner = clamp(gaps.inner, 0...40, defaults.gaps.inner)
        resizeStep = clamp(resizeStep, 5...150, defaults.resizeStep)
        stageManagerInset = clamp(stageManagerInset, 0...200, defaults.stageManagerInset)
        undoDepth = min(max(undoDepth, 0), 100)
        excludedBundleIDs = Array(excludedBundleIDs.prefix(500))
    }

    public func excludes(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedBundleIDs.contains(bundleID)
    }

    // MARK: - JSON

    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func from(jsonData data: Data) throws -> Settings {
        try JSONDecoder().decode(Settings.self, from: data)
    }
}
