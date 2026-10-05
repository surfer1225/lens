import Foundation

/// Decides when layout memory records the arrangement and when it restores one.
///
/// Pure, so the timing rules — the part that is easy to get subtly wrong — are unit-tested;
/// `LayoutManager` feeds it events and carries out the actions.
///
/// The rules exist because macOS rearranges windows in three ways:
///
/// - **A different display setup** (undock, redock). The fingerprint changes; restore the layout
///   remembered for the new setup.
/// - **A brief drop-out.** A display vanishes for a moment and returns (a flaky cable, a KVM, a
///   monitor waking slowly). By the time things settle the fingerprint is back where it started,
///   but macOS has already moved the windows. Restore anyway.
/// - **Sleep and wake,** of the Mac or of its displays. Windows can come back piled on one screen
///   even though the setup looks unchanged. Record the arrangement just before sleep, and restore
///   it shortly after wake.
///
/// Capturing is suspended whenever windows may be wherever macOS dumped them — during a change,
/// while asleep, and briefly after a restore — so the mess never overwrites a good layout.
public struct MemoryPolicy: Sendable {
    public enum Event: Sendable {
        /// The periodic timer fired. `setup` is the display fingerprint right now.
        case tick(setup: DisplayFingerprint)
        /// One raw screen-parameters notification; several arrive per plug or unplug.
        case displaysChanging(setup: DisplayFingerprint)
        /// Notifications stopped arriving (debounced); `setup` is where things landed.
        case displaysSettled(setup: DisplayFingerprint)
        /// The Mac or its displays are about to sleep.
        case sleep
        /// The Mac or its displays woke up.
        case wake
    }

    public enum Action: Equatable, Sendable {
        case none
        /// Record the current arrangement for the current setup.
        case capture
        /// Apply whatever is remembered for this setup.
        case restore(DisplayFingerprint)
    }

    /// How long after a restore before capturing resumes, so a half-applied layout is never
    /// recorded over a good one.
    public static let settleAfterRestore: TimeInterval = 5

    /// How long after wake before restoring, giving displays time to reappear. Displays that
    /// take longer arrive as a normal display change and are handled then.
    public static let settleAfterWake: TimeInterval = 4

    public private(set) var currentSetup: DisplayFingerprint
    public private(set) var isAsleep = false

    private var pausedUntil: Date = .distantPast
    /// A display change in progress passed through a different setup, so windows may have moved
    /// even if it ends where it began.
    private var sawDifferentSetup = false
    /// Set at wake; cleared once the post-wake restore has happened.
    private var wokeAt: Date?

    public init(setup: DisplayFingerprint) {
        self.currentSetup = setup
    }

    /// When the manager should next send a `.tick`, if sooner than its regular timer.
    public var wakeRestoreDue: Date? {
        wokeAt.map { $0.addingTimeInterval(Self.settleAfterWake) }
    }

    public mutating func handle(_ event: Event, at now: Date = Date()) -> Action {
        switch event {
        case .sleep:
            guard !isAsleep else { return .none }
            isAsleep = true
            // Record the arrangement as it is, so the restore after wake puts back exactly this
            // — including anything moved since the last periodic capture.
            return now >= pausedUntil ? .capture : .none

        case .wake:
            // Only a wake that follows a sleep we saw: the Mac and its displays both announce
            // waking, sometimes far apart, and a second restore would undo moves made since.
            guard isAsleep else { return .none }
            isAsleep = false
            wokeAt = now
            pausedUntil = max(pausedUntil, now.addingTimeInterval(Self.settleAfterWake))
            return .none

        case .displaysChanging(let setup):
            if setup != currentSetup { sawDifferentSetup = true }
            return .none

        case .displaysSettled(let setup):
            let passedThroughAnother = sawDifferentSetup
            sawDifferentSetup = false
            guard !isAsleep else { return .none }
            if setup != currentSetup || passedThroughAnother || wokeAt != nil {
                return restore(setup, at: now)
            }
            return .none

        case .tick(let setup):
            guard !isAsleep else { return .none }
            if let due = wakeRestoreDue, now >= due {
                return restore(setup, at: now)
            }
            // A change is in flight; `.displaysSettled` will deal with it.
            guard now >= pausedUntil, setup == currentSetup, !sawDifferentSetup else { return .none }
            return .capture
        }
    }

    private mutating func restore(_ setup: DisplayFingerprint, at now: Date) -> Action {
        currentSetup = setup
        wokeAt = nil
        pausedUntil = now.addingTimeInterval(Self.settleAfterRestore)
        return .restore(setup)
    }
}
