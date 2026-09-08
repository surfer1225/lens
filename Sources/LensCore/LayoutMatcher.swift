import CoreGraphics
import Foundation

/// A window that exists right now, described without reference to the Accessibility API so the
/// matching logic stays pure and testable.
public struct LiveWindow: Equatable, Sendable {
    /// Opaque handle chosen by the caller — in practice the index into its own array of windows.
    public let id: Int
    public let bundleID: String
    public let title: String
    /// Position among this application's windows, in the order the system reports them.
    public let index: Int

    public init(id: Int, bundleID: String, title: String, index: Int) {
        self.id = id
        self.bundleID = bundleID
        self.title = title
        self.index = index
    }
}

/// "Put window `windowID` at `frame`."
public struct LayoutAssignment: Equatable, Sendable {
    public let windowID: Int
    public let frame: CGRect

    public init(windowID: Int, frame: CGRect) {
        self.windowID = windowID
        self.frame = frame
    }
}

/// Works out which of today's windows corresponds to each remembered one.
///
/// This is the part of layout restore that can actually be got wrong, so it lives here as a pure
/// function over plain values. There is no perfect answer: window titles change, apps reopen with
/// a different number of windows, and macOS offers no durable per-window identity across
/// relaunches. The strategy is to use the strongest available signal first and degrade
/// predictably.
public enum LayoutMatcher {
    /// Pairs remembered windows with live ones and returns where each should go.
    ///
    /// Matching runs per application, in two passes:
    ///
    /// 1. **Exact title.** A window titled "Inbox" goes back where "Inbox" was, even if the app
    ///    reopened its windows in a different order — which is the common case after a restart.
    /// 2. **Positional.** Whatever is left over is paired in the order the system reports it.
    ///    This is what carries untitled windows, renamed documents, and apps that reuse one
    ///    title across many windows.
    ///
    /// Anything unmatched is left strictly alone. A window Lens does not recognise is never
    /// moved, and a remembered window whose app is not running is simply dropped — restoring a
    /// layout should never be destructive to windows that were not part of it.
    public static func plan(restoring layout: Layout, onto live: [LiveWindow]) -> [LayoutAssignment] {
        let liveByApp = Dictionary(grouping: live, by: \.bundleID)
        let snapshotsByApp = Dictionary(grouping: layout.snapshots, by: \.bundleID)

        var assignments = [LayoutAssignment]()

        // Sorted for determinism: the same inputs must always produce the same plan.
        for bundleID in snapshotsByApp.keys.sorted() {
            guard let candidates = liveByApp[bundleID]?.sorted(by: { $0.index < $1.index }),
                  !candidates.isEmpty,
                  let snapshots = snapshotsByApp[bundleID]?.sorted(by: { $0.index < $1.index })
            else { continue }

            var claimed = Set<Int>()
            var unmatched = [WindowSnapshot]()

            // Pass 1 — exact title.
            for snapshot in snapshots {
                guard !snapshot.title.isEmpty,
                      let match = candidates.first(where: {
                          !claimed.contains($0.id) && $0.title == snapshot.title
                      })
                else {
                    unmatched.append(snapshot)
                    continue
                }
                claimed.insert(match.id)
                assignments.append(LayoutAssignment(windowID: match.id, frame: snapshot.frame))
            }

            // Pass 2 — positional, over whatever neither pass has claimed.
            var free = candidates.filter { !claimed.contains($0.id) }
            for snapshot in unmatched {
                guard !free.isEmpty else { break }
                let match = free.removeFirst()
                assignments.append(LayoutAssignment(windowID: match.id, frame: snapshot.frame))
            }
        }

        return assignments.sorted { $0.windowID < $1.windowID }
    }
}
