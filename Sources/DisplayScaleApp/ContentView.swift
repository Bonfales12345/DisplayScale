import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: DisplayScaleViewModel
    @State private var showingRemoveConfirmation = false

    var body: some View {
        Form {
            if let display = model.selectedDisplay {
                displaySection(display)
                scaleSection(display)
                modeSection(display)
                actionsSection
            } else {
                emptySection
            }

            Section {
                Button(action: model.refresh) {
                    Label("Refresh Displays", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 12)
        .alert(item: $model.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .confirmationDialog(
            "Remove DisplayScale modes?",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove custom modes", role: .destructive) { model.removeModes() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The saved original override will be restored if DisplayScale created one. Restart your Mac afterward.")
        }
        .onAppear { model.refresh() }
    }

    private func displaySection(_ display: DisplayTarget) -> some View {
        Section("Display") {
            LabeledContent("Screen") {
                if model.displays.count > 1 {
                    Picker("Display", selection: Binding(
                        get: { model.selectedDisplayID },
                        set: { model.selectDisplay($0) }
                    )) {
                        ForEach(model.displays) { item in
                            Text(item.name).tag(Optional(item.id))
                        }
                    }
                    .labelsHidden()
                } else {
                    Text(display.name)
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Native resolution", value: display.nativeSize.label)

            LabeledContent(display.isBuiltIn ? "Selected resolution" : "Looks like") {
                Text(model.selectedLogicalSize?.label ?? "—")
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func scaleSection(_ display: DisplayTarget) -> some View {
        Section {
            if display.isBuiltIn {
                builtInScaleControl()
            } else {
                externalScaleControl(display)
            }
        } header: {
            Text("UI Scale")
        } footer: {
            Text(display.isBuiltIn
                ? "Choose one of the resolutions macOS supports for this panel. Applying a scale changes the display resolution directly."
                : "A higher percentage makes controls larger while keeping text rendered at 2× for sharper edges.")
        }
    }

    private func builtInScaleControl() -> some View {
        let scales = model.availableBuiltInScalePercents
        let currentScale = model.selectedBuiltInMode?.scalePercent ?? scales.first ?? 100
        let selectedIndex = scales.firstIndex(of: currentScale) ?? 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Scale")
                Spacer()
                Text("\(currentScale)%")
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }

            Slider(
                value: Binding(
                    get: { Double(selectedIndex) },
                    set: { index in
                        let clampedIndex = min(max(Int(index.rounded()), 0), max(scales.count - 1, 0))
                        guard scales.indices.contains(clampedIndex) else { return }
                        model.selectBuiltInScale(percent: scales[clampedIndex])
                    }
                ),
                in: 0...Double(max(scales.count - 1, 0)),
                step: 1
            )
            .accessibilityLabel("Built-in display scale")
            .disabled(scales.count <= 1)

            HStack {
                Text("More Space")
                Spacer()
                Text("Larger UI")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func externalScaleControl(_ display: DisplayTarget) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Scale")
                Spacer()
                Text("\(model.scalePercent)%")
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }

            Slider(
                value: Binding(
                    get: { Double(model.scalePercent) },
                    set: { model.scalePercent = Int($0.rounded()) }
                ),
                in: 110...Double(display.maximumScalePercent),
                step: 5
            )
            .accessibilityLabel("External display scale")
            .disabled(display.maximumScalePercent <= 110)

            HStack {
                Text("More Space")
                Spacer()
                Text("Larger UI")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func modeSection(_ display: DisplayTarget) -> some View {
        Section("Mode") {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .fontWeight(.medium)
                    Text(statusDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                statusIcon
            }

            if let status = model.latestStatus {
                Text(status.message)
                    .foregroundStyle(status.style == .success ? Color.green : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if display.isBuiltIn {
                Text("Built-in resolutions use the modes macOS provides. No custom override or restart is needed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("macOS loads display overrides at startup. Restart once after adding or removing modes. The override is shared by identical screen models.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if model.selectedForeignOverrideExists && !model.selectedBackupExists {
                    Text("An existing override will be copied aside before DisplayScale replaces it.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                if model.selectedOverrideInstalled {
                    Button("Remove DisplayScale modes…", role: .destructive) {
                        showingRemoveConfirmation = true
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            HStack {
                Button(action: primaryAction) {
                    Label(primaryTitle, systemImage: primaryIcon)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || (model.selectedDisplayIsBuiltIn && !model.selectedModeLoaded))

                if !model.selectedDisplayIsBuiltIn && model.selectedOverrideInstalled {
                    Button("Update Mode List") { model.installModes() }
                        .disabled(model.isBusy || model.selectedBackupExists && model.selectedForeignOverrideExists)
                }

                Spacer(minLength: 8)

                Button("Displays Settings", action: model.openDisplaysSettings)
            }
        }
    }

    private var emptySection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No display found")
                        .font(.headline)
                    Text("DisplayScale could not find an active screen. Refresh to try again.")
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "display.2")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusTitle: String {
        if model.selectedDisplayIsBuiltIn {
            return model.selectedModeLoaded ? "Built-in resolutions are ready" : "No built-in resolutions found"
        }
        if model.selectedModeLoaded { return "HiDPI scale is ready" }
        if model.selectedOverrideInstalled { return "Restart needed to load this scale" }
        if model.selectedForeignOverrideExists { return "An existing display override was found" }
        return "Custom HiDPI modes are not installed"
    }

    private var statusDescription: String {
        if model.selectedDisplayIsBuiltIn {
            return model.selectedModeLoaded
                ? "Apply the selected macOS resolution to the built-in display."
                : "Refresh the display list and check that macOS can read this panel’s display modes."
        }
        if model.selectedModeLoaded {
            return "Apply the selected percentage as the permanent resolution for this screen."
        }
        if model.selectedOverrideInstalled {
            return "The override is installed. Restart your Mac once, then choose a scale here."
        }
        if model.selectedForeignOverrideExists {
            return "DisplayScale will save a copy of the existing file before adding its scale list."
        }
        return "DisplayScale will add a range of 2× modes derived from this screen’s native pixels."
    }

    private var statusIcon: some View {
        let ready = model.selectedModeLoaded
        let color: Color = ready ? .green : (model.selectedOverrideInstalled ? .orange : .secondary)
        let symbol = ready ? "checkmark.circle.fill" : (model.selectedOverrideInstalled ? "clock.fill" : "display")
        return Image(systemName: symbol)
            .foregroundStyle(color)
    }

    private var primaryTitle: String {
        if model.selectedDisplayIsBuiltIn { return "Set Resolution" }
        if model.selectedModeLoaded { return "Apply \(model.scalePercent)% Scale" }
        if model.selectedOverrideInstalled { return "Refresh HiDPI Modes" }
        return "Add HiDPI Modes"
    }

    private var primaryIcon: String {
        if model.selectedDisplayIsBuiltIn { return "arrow.up.right.circle" }
        return model.selectedModeLoaded ? "arrow.up.right.circle" : "plus.circle"
    }

    private func primaryAction() {
        if model.selectedDisplayIsBuiltIn {
            if model.selectedModeLoaded { model.applyScale() }
            return
        }
        if model.selectedModeLoaded {
            model.applyScale()
        } else {
            model.installModes()
        }
    }
}
