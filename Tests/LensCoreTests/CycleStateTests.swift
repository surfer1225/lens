import CoreGraphics
import Testing

@testable import LensCore

private let exactWindow = WindowID(raw: 42)
private let fuzzyWindow = WindowID(raw: 42, isExact: false)
private let leftHalfKey = CycleKey(window: exactWindow, action: .leftHalf)
private let placed = CGRect(x: 0, y: 0, width: 756, height: 982)

@Suite("Repeated-press cycling")
struct CycleStateTests {
    @Test("The first press of a shortcut always starts at step 0")
    func firstPressIsStepZero() {
        let state = CycleState()
        let index = state.index(
            for: leftHalfKey,
            currentFrame: CGRect(x: 100, y: 100, width: 400, height: 300),
            cycleLength: 3,
            cyclingEnabled: true
        )
        #expect(index == 0)
    }

    @Test("Pressing again with the window untouched advances the cycle and wraps")
    func repeatedPressesAdvance() {
        var state = CycleState()
        var expected = [Int]()
        var frame = CGRect(x: 100, y: 100, width: 400, height: 300)

        for _ in 0..<4 {
            let index = state.index(
                for: leftHalfKey, currentFrame: frame, cycleLength: 3, cyclingEnabled: true
            )
            expected.append(index)
            // Pretend we applied the frame for this step; the exact value does not matter, only
            // that the window is still where we left it on the next press.
            frame = CGRect(x: 0, y: 0, width: CGFloat(100 * (index + 1)), height: 982)
            state.record(key: leftHalfKey, appliedFrame: frame, index: index)
        }

        #expect(expected == [0, 1, 2, 0])
    }

    @Test("Moving the window by hand between presses restarts the cycle")
    func manualResizeResetsCycle() {
        var state = CycleState()
        state.record(key: leftHalfKey, appliedFrame: placed, index: 0)

        let userMoved = CGRect(x: 300, y: 200, width: 500, height: 400)
        let index = state.index(
            for: leftHalfKey, currentFrame: userMoved, cycleLength: 3, cyclingEnabled: true
        )
        #expect(index == 0)
    }

    @Test("Small drift, as from Terminal's character-cell sizing, still counts as unmoved")
    func driftWithinToleranceStillCycles() {
        var state = CycleState()
        state.record(key: leftHalfKey, appliedFrame: placed, index: 0)

        let quantised = CGRect(x: 0, y: 0, width: 752, height: 976)
        let index = state.index(
            for: leftHalfKey, currentFrame: quantised, cycleLength: 3, cyclingEnabled: true
        )
        #expect(index == 1)
    }

    @Test("Drift past the tolerance does not count as unmoved")
    func driftBeyondToleranceResets() {
        var state = CycleState()
        state.record(key: leftHalfKey, appliedFrame: placed, index: 0)

        let moved = CGRect(x: 0, y: 0, width: 700, height: 982)
        let index = state.index(
            for: leftHalfKey, currentFrame: moved, cycleLength: 3, cyclingEnabled: true
        )
        #expect(index == 0)
    }

    @Test("A different action restarts the cycle")
    func differentActionResets() {
        var state = CycleState()
        state.record(key: leftHalfKey, appliedFrame: placed, index: 1)

        let rightHalfKey = CycleKey(window: exactWindow, action: .rightHalf)
        let index = state.index(
            for: rightHalfKey, currentFrame: placed, cycleLength: 3, cyclingEnabled: true
        )
        #expect(index == 0)
    }

    @Test("A different window restarts the cycle")
    func differentWindowResets() {
        var state = CycleState()
        state.record(key: leftHalfKey, appliedFrame: placed, index: 1)

        let otherKey = CycleKey(window: WindowID(raw: 99), action: .leftHalf)
        let index = state.index(
            for: otherKey, currentFrame: placed, cycleLength: 3, cyclingEnabled: true
        )
        #expect(index == 0)
    }

    @Test("Cycling never engages when the window identity came from the fallback hash")
    func inexactIdentityNeverCycles() {
        var state = CycleState()
        let key = CycleKey(window: fuzzyWindow, action: .leftHalf)
        state.record(key: key, appliedFrame: placed, index: 0)

        let index = state.index(
            for: key, currentFrame: placed, cycleLength: 3, cyclingEnabled: true
        )
        #expect(index == 0)
    }

    @Test("Disabling cycling pins every press to step 0, matching Spectacle exactly")
    func disabledCyclingAlwaysReturnsZero() {
        var state = CycleState()
        for _ in 0..<5 {
            let index = state.index(
                for: leftHalfKey, currentFrame: placed, cycleLength: 3, cyclingEnabled: false
            )
            #expect(index == 0)
            state.record(key: leftHalfKey, appliedFrame: placed, index: index)
        }
    }

    @Test("A single-step action never reports a non-zero index")
    func singleStepActionsDoNotCycle() {
        var state = CycleState()
        let key = CycleKey(window: exactWindow, action: .fullscreen)
        state.record(key: key, appliedFrame: placed, index: 0)

        let index = state.index(
            for: key, currentFrame: placed, cycleLength: 1, cyclingEnabled: true
        )
        #expect(index == 0)
    }

    @Test("Reset clears the chain")
    func resetClearsChain() {
        var state = CycleState()
        state.record(key: leftHalfKey, appliedFrame: placed, index: 0)
        state.reset()

        let index = state.index(
            for: leftHalfKey, currentFrame: placed, cycleLength: 3, cyclingEnabled: true
        )
        #expect(index == 0)
    }
}
