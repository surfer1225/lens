import LensCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if !model.authorizer.isTrusted {
                AccessibilityBanner(model: model)
            }

            TabView {
                ShortcutsTab(model: model)
                    .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                GeneralTab(model: model)
                    .tabItem { Label("General", systemImage: "gearshape") }
                ExclusionsTab(model: model)
                    .tabItem { Label("Exclusions", systemImage: "nosign") }
            }
            .padding(.top, 8)
        }
        .frame(width: 680, height: 560)
    }
}

/// Shown until Accessibility access is granted. Every shortcut is inert until then, so this
/// stays visible rather than appearing once and being missed.
private struct AccessibilityBanner: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Lens cannot move windows yet")
                    .font(.headline)
                Text("Grant Accessibility access to enable every shortcut below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Open System Settings") {
                model.authorizer.openSystemSettings()
            }
        }
        .padding(12)
        .background(.orange.opacity(0.12))
    }
}
