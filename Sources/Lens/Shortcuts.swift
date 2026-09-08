import KeyboardShortcuts
import LensCore

/// Maps every action to a global hotkey.
///
/// `KeyboardShortcuts` registers through Carbon's `RegisterEventHotKey`, which is still the only
/// supported way to *consume* a global key combination — `NSEvent.addGlobalMonitorForEvents` can
/// observe but not swallow, so the keystroke would also reach the frontmost app. Registering a
/// hotkey needs no permission; only moving windows requires Accessibility.
///
/// Main-actor isolated because `KeyboardShortcuts.Name` is not `Sendable`, and every caller —
/// the app model and the Settings views — is on the main actor anyway.
@MainActor
enum Shortcuts {
    /// Built once, because `KeyboardShortcuts.Name(_:default:)` registers the default the first
    /// time a name is constructed.
    static let names: [WindowAction: KeyboardShortcuts.Name] = {
        var names = [WindowAction: KeyboardShortcuts.Name]()
        for action in WindowAction.allCases {
            names[action] = KeyboardShortcuts.Name(
                action.rawValue,
                default: defaultShortcut(for: action)
            )
        }
        return names
    }()

    static func name(for action: WindowAction) -> KeyboardShortcuts.Name {
        // `names` is built from allCases, so the lookup cannot miss. Falling back to an unbound
        // name rather than force-unwrapping means a future action added without rebuilding the
        // table degrades to "no shortcut" instead of crashing the app on launch.
        names[action] ?? KeyboardShortcuts.Name(action.rawValue)
    }

    static func resetAllToDefaults() {
        KeyboardShortcuts.reset(Array(names.values))
    }

    private typealias Shortcut = KeyboardShortcuts.Shortcut

    /// Spectacle 1.2's defaults, reproduced exactly so existing muscle memory keeps working.
    /// Everything Lens adds beyond Spectacle ships unbound.
    private static func defaultShortcut(for action: WindowAction) -> Shortcut? {
        switch action {
        case .center:
            Shortcut(.c, modifiers: [.option, .command])
        case .fullscreen:
            Shortcut(.f, modifiers: [.option, .command])

        case .leftHalf:
            Shortcut(.leftArrow, modifiers: [.option, .command])
        case .rightHalf:
            Shortcut(.rightArrow, modifiers: [.option, .command])
        case .topHalf:
            Shortcut(.upArrow, modifiers: [.option, .command])
        case .bottomHalf:
            Shortcut(.downArrow, modifiers: [.option, .command])

        case .upperLeft:
            Shortcut(.leftArrow, modifiers: [.control, .command])
        case .lowerLeft:
            Shortcut(.leftArrow, modifiers: [.control, .shift, .command])
        case .upperRight:
            Shortcut(.rightArrow, modifiers: [.control, .command])
        case .lowerRight:
            Shortcut(.rightArrow, modifiers: [.control, .shift, .command])

        case .nextDisplay:
            Shortcut(.rightArrow, modifiers: [.control, .option, .command])
        case .previousDisplay:
            Shortcut(.leftArrow, modifiers: [.control, .option, .command])

        case .nextThird:
            Shortcut(.rightArrow, modifiers: [.control, .option])
        case .previousThird:
            Shortcut(.leftArrow, modifiers: [.control, .option])

        case .makeLarger:
            Shortcut(.rightArrow, modifiers: [.control, .option, .shift])
        case .makeSmaller:
            Shortcut(.leftArrow, modifiers: [.control, .option, .shift])

        case .undo:
            Shortcut(.z, modifiers: [.option, .command])
        case .redo:
            Shortcut(.z, modifiers: [.option, .shift, .command])

        default:
            nil
        }
    }
}
