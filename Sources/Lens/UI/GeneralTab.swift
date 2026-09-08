import AppKit
import LensAX
import LensCore
import SwiftUI
import UniformTypeIdentifiers

struct GeneralTab: View {
    @Bindable var model: AppModel

    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch Lens at login", isOn: $model.launchesAtLogin)
            }

            Section("Pressing a shortcut again") {
                Picker("When already in position", selection: $model.settings.subsequentExecution) {
                    ForEach(SubsequentExecution.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(subsequentExecutionHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Spacing") {
                PointStepper(
                    title: "Screen edges",
                    value: $model.settings.gaps.outer,
                    range: 0...40
                )
                PointStepper(
                    title: "Between windows",
                    value: $model.settings.gaps.inner,
                    range: 0...40
                )
                Text("macOS 26's own tiling adds margins too — match these to it under "
                     + "System Settings › Desktop & Dock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Resizing") {
                PointStepper(
                    title: "Make Larger / Smaller step",
                    value: $model.settings.resizeStep,
                    range: 5...150,
                    step: 5
                )
            }

            Section("Compatibility") {
                Toggle(
                    "Leave fullscreen before moving a window",
                    isOn: $model.settings.unfullscreenBeforeMoving
                )
                Text("macOS ignores position changes on a fullscreen window, so without this "
                     + "shortcuts appear to do nothing there.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                PointStepper(
                    title: "Reserve space for Stage Manager",
                    value: $model.settings.stageManagerInset,
                    range: 0...200,
                    step: 8
                )
                Text(stageManagerHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Configuration") {
                HStack {
                    Button("Export…") { export() }
                    Button("Import…") { importSettings() }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var subsequentExecutionHint: String {
        switch model.settings.subsequentExecution {
        case .moveToAdjacentDisplay:
            "Spectacle's behaviour: ⌥⌘← puts a window on the left half, then a second press "
                + "carries it to the display on the left. With no display that way, it cycles "
                + "sizes instead."
        case .cycleSizes:
            "⌥⌘← puts a window on the left half, then a third, then two thirds. Windows never "
                + "leave the display they are on."
        case .repeatSameFrame:
            "Every press applies the same frame."
        }
    }

    private var stageManagerHint: String {
        ScreenDetector.isStageManagerEnabled
            ? "Stage Manager is on. macOS does not exclude its strip from the usable area, "
                + "so this much is held back on the left."
            : "Stage Manager is off, so this has no effect right now."
    }

    // MARK: - Import / export

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Lens Settings.json"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.exportSettings(to: url)
            errorMessage = nil
        } catch {
            errorMessage = "Could not export: \(error.localizedDescription)"
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.importSettings(from: url)
            errorMessage = nil
        } catch {
            errorMessage = "Could not import: \(error.localizedDescription)"
        }
    }
}

/// A labelled stepper over a point measurement, with the current value shown beside it.
private struct PointStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 2

    var body: some View {
        LabeledContent(title) {
            Stepper(value: $value, in: range, step: step) {
                Text("\(Int(value)) pt")
                    .monospacedDigit()
                    .frame(width: 52, alignment: .leading)
            }
        }
    }
}
