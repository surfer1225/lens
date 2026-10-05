import CoreGraphics
import Foundation
import Testing

@testable import LensCore

private func snapshot(
    _ bundleID: String, _ title: String, index: Int = 0, x: CGFloat = 0, y: CGFloat = 0
) -> WindowSnapshot {
    WindowSnapshot(
        bundleID: bundleID, title: title, index: index,
        frame: CGRect(x: x, y: y, width: 100, height: 100)
    )
}

private func live(_ id: Int, _ bundleID: String, _ title: String, index: Int = 0) -> LiveWindow {
    LiveWindow(id: id, bundleID: bundleID, title: title, index: index)
}

private func layout(_ snapshots: [WindowSnapshot]) -> Layout {
    Layout(fingerprint: DisplayFingerprint(value: "test"), snapshots: snapshots)
}

@Suite("Display fingerprinting")
struct DisplayFingerprintTests {
    private let builtIn = ScreenDescriptor(
        name: "Built-in Retina Display", frame: CGRect(x: 0, y: 0, width: 1512, height: 982)
    )
    private let external = ScreenDescriptor(
        name: "Studio Display", frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440)
    )

    @Test("The same setup fingerprints identically regardless of enumeration order")
    func orderIndependent() {
        #expect(
            DisplayFingerprint(screens: [builtIn, external])
                == DisplayFingerprint(screens: [external, builtIn])
        )
    }

    @Test("Laptop alone and laptop-plus-monitor are different setups")
    func differentSetupsDiffer() {
        #expect(DisplayFingerprint(screens: [builtIn]) != DisplayFingerprint(screens: [builtIn, external]))
    }

    @Test("Moving a display to the other side is a different setup")
    func arrangementMatters() {
        let onTheLeft = ScreenDescriptor(
            name: "Studio Display", frame: CGRect(x: -2560, y: 0, width: 2560, height: 1440)
        )
        #expect(
            DisplayFingerprint(screens: [builtIn, external])
                != DisplayFingerprint(screens: [builtIn, onTheLeft])
        )
    }

    @Test("Changing resolution is a different setup, so stale frames are never reused")
    func resolutionMatters() {
        let scaled = ScreenDescriptor(
            name: "Studio Display", frame: CGRect(x: 1512, y: 0, width: 1920, height: 1080)
        )
        #expect(
            DisplayFingerprint(screens: [builtIn, external])
                != DisplayFingerprint(screens: [builtIn, scaled])
        )
    }

    @Test("Fingerprints survive a JSON round trip")
    func codable() throws {
        let original = DisplayFingerprint(screens: [builtIn, external])
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(DisplayFingerprint.self, from: data) == original)
    }
}

@Suite("Layout matching")
struct LayoutMatcherTests {
    @Test("A window is restored to where its title was")
    func matchesByTitle() {
        let plan = LayoutMatcher.plan(
            restoring: layout([snapshot("com.apple.Safari", "Inbox", x: 500)]),
            onto: [live(0, "com.apple.Safari", "Inbox")]
        )
        #expect(plan == [LayoutAssignment(windowID: 0, frame: CGRect(x: 500, y: 0, width: 100, height: 100))])
    }

    @Test("Titles win over ordering, so a reopened app still lands correctly")
    func titleBeatsOrder() {
        // Captured as [Inbox, Drafts]; the app reopened them the other way round.
        let saved = layout([
            snapshot("m", "Inbox", index: 0, x: 0),
            snapshot("m", "Drafts", index: 1, x: 900),
        ])
        let plan = LayoutMatcher.plan(
            restoring: saved,
            onto: [live(0, "m", "Drafts", index: 0), live(1, "m", "Inbox", index: 1)]
        )
        #expect(plan == [
            LayoutAssignment(windowID: 0, frame: CGRect(x: 900, y: 0, width: 100, height: 100)),
            LayoutAssignment(windowID: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
        ])
    }

    @Test("Untitled windows fall back to positional matching")
    func untitledUsesOrder() {
        let saved = layout([
            snapshot("term", "", index: 0, x: 0),
            snapshot("term", "", index: 1, x: 700),
        ])
        let plan = LayoutMatcher.plan(
            restoring: saved,
            onto: [live(0, "term", "", index: 0), live(1, "term", "", index: 1)]
        )
        #expect(plan.map(\.frame.origin.x) == [0, 700])
    }

    @Test("Windows sharing one title are disambiguated by position, not collapsed")
    func duplicateTitles() {
        let saved = layout([
            snapshot("chrome", "New Tab", index: 0, x: 0),
            snapshot("chrome", "New Tab", index: 1, x: 800),
        ])
        let plan = LayoutMatcher.plan(
            restoring: saved,
            onto: [live(0, "chrome", "New Tab", index: 0), live(1, "chrome", "New Tab", index: 1)]
        )
        #expect(plan.count == 2)
        #expect(Set(plan.map(\.windowID)) == [0, 1])
        #expect(Set(plan.map(\.frame.origin.x)) == [0, 800])
    }

    @Test("A window Lens does not recognise is never moved")
    func unknownWindowsUntouched() {
        let plan = LayoutMatcher.plan(
            restoring: layout([snapshot("known", "A")]),
            onto: [live(0, "known", "A"), live(1, "stranger", "B")]
        )
        #expect(plan.map(\.windowID) == [0])
    }

    @Test("Remembered windows whose app is not running are dropped")
    func missingAppsDropped() {
        let plan = LayoutMatcher.plan(
            restoring: layout([snapshot("gone", "A"), snapshot("here", "B", x: 300)]),
            onto: [live(0, "here", "B")]
        )
        #expect(plan == [LayoutAssignment(windowID: 0, frame: CGRect(x: 300, y: 0, width: 100, height: 100))])
    }

    @Test("Extra live windows are left alone when the app has gained windows")
    func moreLiveThanRemembered() {
        let plan = LayoutMatcher.plan(
            restoring: layout([snapshot("app", "", index: 0)]),
            onto: [live(0, "app", "", index: 0), live(1, "app", "", index: 1)]
        )
        #expect(plan.map(\.windowID) == [0])
    }

    @Test("Extra remembered windows are ignored when the app has fewer now")
    func moreRememberedThanLive() {
        let saved = layout([
            snapshot("app", "", index: 0, x: 0),
            snapshot("app", "", index: 1, x: 400),
            snapshot("app", "", index: 2, x: 800),
        ])
        let plan = LayoutMatcher.plan(restoring: saved, onto: [live(0, "app", "", index: 0)])
        #expect(plan.count == 1)
    }

    @Test("No window is ever assigned two frames")
    func assignmentsAreUnique() {
        let saved = layout([
            snapshot("app", "Same", index: 0, x: 0),
            snapshot("app", "Same", index: 1, x: 500),
            snapshot("app", "Same", index: 2, x: 900),
        ])
        let plan = LayoutMatcher.plan(
            restoring: saved,
            onto: [live(0, "app", "Same", index: 0), live(1, "app", "Same", index: 1)]
        )
        #expect(plan.count == Set(plan.map(\.windowID)).count)
        #expect(plan.count == 2)
    }

    @Test("Matching is deterministic across repeated runs")
    func deterministic() {
        let saved = layout([
            snapshot("a", "one", index: 0, x: 10),
            snapshot("b", "two", index: 0, x: 20),
            snapshot("a", "three", index: 1, x: 30),
        ])
        let windows = [
            live(0, "a", "three", index: 0), live(1, "b", "two", index: 0),
            live(2, "a", "one", index: 1),
        ]
        let first = LayoutMatcher.plan(restoring: saved, onto: windows)
        for _ in 0..<20 {
            #expect(LayoutMatcher.plan(restoring: saved, onto: windows) == first)
        }
    }

    @Test("An empty layout moves nothing")
    func emptyLayout() {
        #expect(LayoutMatcher.plan(restoring: layout([]), onto: [live(0, "a", "b")]).isEmpty)
    }

    @Test("No live windows means nothing to do")
    func noLiveWindows() {
        #expect(LayoutMatcher.plan(restoring: layout([snapshot("a", "b")]), onto: []).isEmpty)
    }
}

@Suite("Layout library")
struct LayoutLibraryTests {
    private let fingerprint = DisplayFingerprint(value: "laptop+monitor")

    @Test("Layouts are stored and retrieved per display setup")
    func storeAndFetch() {
        var library = LayoutLibrary()
        library.store(Layout(fingerprint: fingerprint, snapshots: [snapshot("a", "b")]))

        #expect(library.layout(for: fingerprint)?.snapshots.count == 1)
        #expect(library.layout(for: DisplayFingerprint(value: "other")) == nil)
    }

    @Test("An empty layout is not stored, so a transient empty desktop cannot erase a good one")
    func emptyLayoutsRejected() {
        var library = LayoutLibrary()
        library.store(Layout(fingerprint: fingerprint, snapshots: [snapshot("a", "b")]))
        library.store(Layout(fingerprint: fingerprint, snapshots: []))

        #expect(library.layout(for: fingerprint)?.snapshots.count == 1)
    }

    @Test("Storing again replaces the previous layout for that setup")
    func storeReplaces() {
        var library = LayoutLibrary()
        library.store(Layout(fingerprint: fingerprint, snapshots: [snapshot("a", "old")]))
        library.store(Layout(fingerprint: fingerprint, snapshots: [snapshot("a", "new")]))

        #expect(library.layout(for: fingerprint)?.snapshots.first?.title == "new")
        #expect(library.count == 1)
    }

    @Test("Forgetting one setup leaves the others alone")
    func forget() {
        var library = LayoutLibrary()
        let other = DisplayFingerprint(value: "laptop")
        library.store(Layout(fingerprint: fingerprint, snapshots: [snapshot("a", "b")]))
        library.store(Layout(fingerprint: other, snapshots: [snapshot("c", "d")]))

        library.forget(fingerprint)
        #expect(library.layout(for: fingerprint) == nil)
        #expect(library.layout(for: other) != nil)
    }

    @Test("The whole library survives a JSON round trip")
    func codable() throws {
        var library = LayoutLibrary()
        library.store(Layout(fingerprint: fingerprint, snapshots: [snapshot("a", "b", x: 42)]))

        let data = try JSONEncoder().encode(library)
        let decoded = try JSONDecoder().decode(LayoutLibrary.self, from: data)
        #expect(decoded.layout(for: fingerprint)?.snapshots.first?.frame.origin.x == 42)
    }
}

@Suite("Security hardening")
struct SecurityHardeningTests {
    @Test("Titles are stored as keyed digests; empty titles stay empty")
    func titleDigest() {
        let digest = TitleDigest(key: Data(repeating: 7, count: 32))
        let stored = digest.digest("Q3 salary review.xlsx")
        #expect(TitleDigest.isDigest(stored))
        #expect(!stored.contains("salary"))
        #expect(digest.digest("Q3 salary review.xlsx") == stored)
        #expect(digest.digest(stored) == stored)  // Never digested twice.
        #expect(digest.digest("") == "")
        #expect(TitleDigest(key: Data(repeating: 8, count: 32)).digest("Q3 salary review.xlsx") != stored)
    }

    @Test("Old layouts' titles are converted to digests")
    func migration() {
        let digest = TitleDigest(key: Data(repeating: 1, count: 32))
        var library = LayoutLibrary()
        library.store(layout([snapshot("com.apple.mail", "Inbox – Secret project")]))
        let migrated = library.mappingTitles(digest.digest)
        let title = migrated.layout(for: DisplayFingerprint(value: "test"))?.snapshots.first?.title ?? ""
        #expect(TitleDigest.isDigest(title))
    }

    @Test("Only the most recently used display setups are kept")
    func setupCap() {
        var library = LayoutLibrary()
        for index in 0..<(LayoutLibrary.maximumSetups + 5) {
            library.store(Layout(
                fingerprint: DisplayFingerprint(value: "setup-\(index)"),
                snapshots: [snapshot("a", "x")],
                capturedAt: Date(timeIntervalSince1970: Double(index))))
        }
        #expect(library.count == LayoutLibrary.maximumSetups)
        #expect(library.layout(for: DisplayFingerprint(value: "setup-0")) == nil)
        #expect(library.layout(for: DisplayFingerprint(value: "setup-24")) != nil)
    }

    @Test("Imported settings are clamped to supported ranges")
    func clampedImport() throws {
        let json = #"{"undoDepth": -1, "resizeStep": 1e300, "gaps": {"outer": -5, "inner": 1e9}, "stageManagerInset": 9999}"#
        let settings = try Settings.from(jsonData: Data(json.utf8))
        #expect(settings.undoDepth == 0)
        #expect(settings.resizeStep == 150)
        #expect(settings.gaps.outer == 0)
        #expect(settings.gaps.inner == 40)
        #expect(settings.stageManagerInset == 200)
    }

    @Test("Nonsense window geometry never traps")
    func hostileGeometry() {
        let work = CGRect(x: 0, y: 0, width: 1000, height: 800)
        for bad in [CGFloat.nan, .infinity, -.infinity, 1e300] {
            let window = CGRect(x: bad, y: 0, width: 100, height: 100)
            #expect((0...2).contains(RectCalculator.horizontalThirdIndex(of: window, in: work)))
            #expect(!window.isReasonable)
        }
        #expect(CGRect(x: 10, y: 10, width: 500, height: 400).isReasonable)
    }
}
