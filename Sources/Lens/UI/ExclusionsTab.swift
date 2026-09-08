import AppKit
import LensCore
import SwiftUI

/// Apps Lens leaves alone.
///
/// Useful for anything that manages its own window geometry — virtual machines, games, or an
/// app whose windows react badly to being resized programmatically.
struct ExclusionsTab: View {
    @Bindable var model: AppModel

    @State private var selection: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lens ignores shortcuts while one of these apps is frontmost.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List(selection: $selection) {
                ForEach(model.settings.excludedBundleIDs, id: \.self) { bundleID in
                    HStack(spacing: 8) {
                        icon(for: bundleID)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(displayName(for: bundleID))
                            Text(bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(bundleID)
                }
            }
            .overlay {
                if model.settings.excludedBundleIDs.isEmpty {
                    ContentUnavailableView(
                        "No Excluded Apps",
                        systemImage: "checkmark.circle",
                        description: Text("Lens works in every app.")
                    )
                }
            }

            HStack {
                Menu("Add App") {
                    ForEach(addableApps) { app in
                        Button(app.name) { add(app.id) }
                    }
                }
                .fixedSize()

                Button("Remove", role: .destructive) { removeSelected() }
                    .disabled(selection.isEmpty)

                Spacer()
            }
        }
        .padding(20)
    }

    // MARK: - Running applications

    /// A running app that could be excluded. `id` is the bundle identifier.
    private struct AppEntry: Identifiable {
        let id: String
        let name: String
    }

    private var addableApps: [AppEntry] {
        let excluded = Set(model.settings.excludedBundleIDs)
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier, !excluded.contains(bundleID) else {
                    return nil
                }
                return AppEntry(id: bundleID, name: app.localizedName ?? bundleID)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func add(_ bundleID: String) {
        guard !model.settings.excludedBundleIDs.contains(bundleID) else { return }
        model.settings.excludedBundleIDs.append(bundleID)
    }

    private func removeSelected() {
        model.settings.excludedBundleIDs.removeAll { selection.contains($0) }
        selection.removeAll()
    }

    // MARK: - Presentation

    private func displayName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return bundleID
        }
        return FileManager.default.displayName(atPath: url.path)
    }

    @ViewBuilder
    private func icon(for bundleID: String) -> some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: "questionmark.app")
                .frame(width: 20, height: 20)
        }
    }
}
