import KeyboardShortcuts
import LensCore
import SwiftUI

/// The shortcut table, laid out in the same two columns Spectacle used so the migration is
/// visually obvious.
struct ShortcutsTab: View {
    @Bindable var model: AppModel

    @State private var showAdditions = false
    @State private var confirmingRestore = false

    private let leftColumn: [[WindowAction]] = [
        [.center, .fullscreen],
        [.leftHalf, .rightHalf, .topHalf, .bottomHalf],
        [.upperLeft, .lowerLeft, .upperRight, .lowerRight],
    ]

    private let rightColumn: [[WindowAction]] = [
        [.nextDisplay, .previousDisplay],
        [.nextThird, .previousThird],
        [.makeLarger, .makeSmaller],
        [.undo, .redo],
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 36) {
                    column(leftColumn)
                    column(rightColumn)
                }

                Divider()

                DisclosureGroup(isExpanded: $showAdditions) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(WindowAction.additions, id: \.self) { action in
                            ShortcutRow(action: action)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Additional actions (\(WindowAction.additions.count))")
                        .font(.headline)
                }

                HStack {
                    Spacer()
                    Button("Restore Defaults…") { confirmingRestore = true }
                }
            }
            .padding(20)
        }
        .confirmationDialog(
            "Restore all shortcuts and settings to their defaults?",
            isPresented: $confirmingRestore,
            titleVisibility: .visible
        ) {
            Button("Restore Defaults", role: .destructive) { model.restoreDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Shortcuts return to Spectacle's originals and every other setting is reset.")
        }
    }

    private func column(_ groups: [[WindowAction]]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(groups.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(groups[index], id: \.self) { ShortcutRow(action: $0) }
                }
            }
        }
    }
}

private struct ShortcutRow: View {
    let action: WindowAction

    var body: some View {
        HStack(spacing: 8) {
            Text("\(action.title):")
                .frame(width: 132, alignment: .trailing)
            KeyboardShortcuts.Recorder(for: Shortcuts.name(for: action))
        }
    }
}
