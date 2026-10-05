import Foundation
import Testing

@testable import LensCore

private let desk = DisplayFingerprint(value: "laptop|monitor")
private let laptop = DisplayFingerprint(value: "laptop")
private let t0 = Date(timeIntervalSinceReferenceDate: 0)

private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

@Suite("Layout memory policy")
struct MemoryPolicyTests {
    @Test("Records while the setup is stable")
    func capturesWhenStable() {
        var policy = MemoryPolicy(setup: desk)
        #expect(policy.handle(.tick(setup: desk), at: at(30)) == .capture)
    }

    @Test("Undocking restores the layout remembered for the new setup")
    func restoresOnNewSetup() {
        var policy = MemoryPolicy(setup: desk)
        _ = policy.handle(.displaysChanging(setup: laptop), at: at(0))
        #expect(policy.handle(.displaysSettled(setup: laptop), at: at(2)) == .restore(laptop))
        #expect(policy.currentSetup == laptop)
    }

    @Test("Does not record mid-change or just after a restore")
    func noCaptureWhileUnsettled() {
        var policy = MemoryPolicy(setup: desk)
        _ = policy.handle(.displaysChanging(setup: laptop), at: at(0))
        #expect(policy.handle(.tick(setup: laptop), at: at(1)) == .none)

        _ = policy.handle(.displaysSettled(setup: laptop), at: at(2))
        #expect(policy.handle(.tick(setup: laptop), at: at(4)) == .none)
        #expect(policy.handle(.tick(setup: laptop), at: at(2 + MemoryPolicy.settleAfterRestore)) == .capture)
    }

    @Test("A display that drops out and returns still triggers a restore")
    func restoresAfterBriefDropOut() {
        var policy = MemoryPolicy(setup: desk)
        _ = policy.handle(.displaysChanging(setup: laptop), at: at(0))
        _ = policy.handle(.displaysChanging(setup: desk), at: at(0.5))
        #expect(policy.handle(.displaysSettled(setup: desk), at: at(2)) == .restore(desk))
    }

    @Test("Notifications that never leave the setup restore nothing")
    func ignoresChangesWithinTheSameSetup() {
        var policy = MemoryPolicy(setup: desk)
        _ = policy.handle(.displaysChanging(setup: desk), at: at(0))
        #expect(policy.handle(.displaysSettled(setup: desk), at: at(2)) == .none)
        #expect(policy.handle(.tick(setup: desk), at: at(30)) == .capture)
    }

    @Test("Records just before sleep, and not while asleep")
    func capturesBeforeSleep() {
        var policy = MemoryPolicy(setup: desk)
        #expect(policy.handle(.sleep, at: at(0)) == .capture)
        #expect(policy.handle(.sleep, at: at(1)) == .none)
        #expect(policy.handle(.tick(setup: laptop), at: at(30)) == .none)
        #expect(policy.handle(.displaysSettled(setup: laptop), at: at(31)) == .none)
    }

    @Test("Waking with the same setup restores the pre-sleep layout")
    func restoresAfterWakeWithSameSetup() {
        var policy = MemoryPolicy(setup: desk)
        _ = policy.handle(.sleep, at: at(0))
        _ = policy.handle(.wake, at: at(100))

        #expect(policy.wakeRestoreDue == at(100 + MemoryPolicy.settleAfterWake))
        #expect(policy.handle(.tick(setup: desk), at: at(101)) == .none)
        #expect(policy.handle(.tick(setup: desk), at: at(100 + MemoryPolicy.settleAfterWake)) == .restore(desk))
        #expect(policy.wakeRestoreDue == nil)
    }

    @Test("Display notifications at wake trigger the restore, once")
    func wakeRestoreViaDisplayChange() {
        var policy = MemoryPolicy(setup: desk)
        _ = policy.handle(.sleep, at: at(0))
        _ = policy.handle(.wake, at: at(100))
        #expect(policy.handle(.displaysSettled(setup: desk), at: at(102)) == .restore(desk))
        // The wake restore is not repeated when its timer fires.
        #expect(policy.handle(.tick(setup: desk), at: at(100 + MemoryPolicy.settleAfterWake)) == .none)
        #expect(policy.handle(.tick(setup: desk), at: at(102 + MemoryPolicy.settleAfterRestore)) == .capture)
    }

    @Test("A monitor slower to wake than the Mac is restored when it arrives")
    func slowMonitorAfterWake() {
        var policy = MemoryPolicy(setup: desk)
        _ = policy.handle(.sleep, at: at(0))
        _ = policy.handle(.wake, at: at(100))
        // The monitor is not back yet when the wake restore is due.
        #expect(policy.handle(.tick(setup: laptop), at: at(105)) == .restore(laptop))
        // Then it arrives.
        _ = policy.handle(.displaysChanging(setup: desk), at: at(112))
        #expect(policy.handle(.displaysSettled(setup: desk), at: at(114)) == .restore(desk))
    }
}
