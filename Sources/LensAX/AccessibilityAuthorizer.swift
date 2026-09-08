import AppKit
import ApplicationServices
import Observation

/// Tracks whether the user has granted Lens control of other applications' windows.
///
/// Nothing Lens does works without this, so the app watches for the grant rather than making the
/// user relaunch: macOS does not notify a process when its Accessibility trust changes, so short
/// of an undocumented notification the only reliable option is to poll.
@MainActor
@Observable
public final class AccessibilityAuthorizer {
    public private(set) var isTrusted: Bool

    /// Called once, the moment trust is granted.
    public var onTrusted: (() -> Void)?

    private var pollTimer: Timer?

    public init() {
        self.isTrusted = AXIsProcessTrusted()
    }

    /// Asks macOS for Accessibility access, showing the system prompt the first time.
    ///
    /// The system only shows its prompt once per app; afterwards the user has to go to System
    /// Settings themselves, which is what `openSystemSettings()` is for.
    public func request() {
        guard !isTrusted else { return }

        // The literal, rather than `kAXTrustedCheckOptionPrompt`: the C header declares that
        // symbol as a mutable global, so Swift 6 rejects reading it as shared mutable state.
        // The value is documented and fixed.
        let options: [String: Any] = ["AXTrustedCheckOptionPrompt": true]
        isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if isTrusted {
            onTrusted?()
        } else {
            startPolling()
        }
    }

    /// Re-reads the current state without prompting.
    @discardableResult
    public func refresh() -> Bool {
        let trusted = AXIsProcessTrusted()
        if trusted, !isTrusted {
            isTrusted = true
            stopPolling()
            onTrusted?()
        } else {
            isTrusted = trusted
        }
        return trusted
    }

    public func openSystemSettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
        if let url { NSWorkspace.shared.open(url) }
    }

    // MARK: - Polling

    private func startPolling() {
        guard pollTimer == nil else { return }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                _ = self.refresh()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
