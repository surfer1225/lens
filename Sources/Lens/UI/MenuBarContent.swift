import LensCore
import SwiftUI

struct MenuBarContent: View {
    @Bindable var model: AppModel

    private static let quickActions: [WindowAction] = [
        .leftHalf, .rightHalf, .topHalf, .bottomHalf,
        .upperLeft, .upperRight, .lowerLeft, .lowerRight,
        .center, .fullscreen,
    ]

    var body: some View {
        if !model.authorizer.isTrusted {
            Button("Grant Accessibility Access…") {
                model.authorizer.openSystemSettings()
            }
            Divider()
        }

        ForEach(Self.quickActions, id: \.self) { action in
            Button(action.title) { model.perform(action) }
        }

        Divider()

        Button("Undo") { model.perform(.undo) }
        Button("Redo") { model.perform(.redo) }

        Divider()

        Section("Layout — \(model.layouts.currentSetupDescription)") {
            // "Update" rather than "Save": Lens records the arrangement continuously, so an
            // explicit action refreshes the running record rather than pinning a snapshot that
            // the next automatic capture would silently overwrite.
            Button("Update Remembered Layout") { model.layouts.saveCurrentLayout() }
            Button("Restore Remembered Layout") { model.layouts.restoreSavedLayout() }
                .disabled(!model.layouts.hasSavedLayoutForCurrentSetup)
            Button("Forget This Setup") { model.layouts.forgetCurrentLayout() }
                .disabled(!model.layouts.hasSavedLayoutForCurrentSetup)
        }

        Divider()

        Toggle("Launch at Login", isOn: $model.launchesAtLogin)

        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Lens") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}
