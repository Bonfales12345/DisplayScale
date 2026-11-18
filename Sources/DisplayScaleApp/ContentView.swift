import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: DisplayScaleViewModel
    @State private var showingRemoveConfirmation = false

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if model.displays.isEmpty {
                        emptyState
                    } else if let display = model.selectedDisplay {
                        displaySelector
                        displaySummary(display)
                        scalePicker(display)
                        scalePreview(display)
                        actionArea
                        footer(display)
                    }

                    Button(action: model.refresh) {
                        Label("Refresh Displays", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                }
                .padding(30)
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
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

    private var displaySelector: some View {
        HStack(spacing: 12) {
            Image(systemName: "display")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("DISPLAY")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text(model.selectedDisplay?.name ?? "Display")
                    .font(.system(size: 15, weight: .medium))
            }

            Spacer()

            if model.displays.count > 1 {
                Picker("Display", selection: Binding(
                    get: { model.selectedDisplayID },
                    set: { model.selectDisplay($0) }
                )) {
                    ForEach(model.displays) { display in
                        Text(display.name).tag(Optional(display.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 250)
            } else {
                Text(model.selectedDisplayIsBuiltIn ? "Built-in display" : "External display")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .panelStyle()
    }

    private func displaySummary(_ display: DisplayTarget) -> some View {
        HStack(spacing: 14) {
            ResolutionTile(
                eyebrow: display.isBuiltIn ? "BUILT-IN PANEL" : "NATIVE PANEL",
                value: display.nativeSize.label,
                detail: display.nativeResolutionSource,
                symbol: "viewfinder",
                tint: .accentColor
            )
            ResolutionTile(
                eyebrow: display.isBuiltIn ? "SELECTED RESOLUTION" : "SCALE PREVIEW",
                value: (model.selectedLogicalSize.map { "\($0.label) UI" }) ?? "—",
                detail: display.isBuiltIn
                    ? (model.selectedBuiltInMode?.pixelSize.label ?? "macOS display mode")
                    : "\(model.selectedLogicalSize.map { PixelSize(width: $0.width * 2, height: $0.height * 2).label } ?? "—") HiDPI render",
                symbol: "sparkles",
                tint: .accentColor
            )
        }
    }

    @ViewBuilder
    private func scalePicker(_ display: DisplayTarget) -> some View {
        if display.isBuiltIn {
            builtInResolutionPicker(display)
        } else {
            externalScalePicker(display)
        }
    }

    private func builtInResolutionPicker(_ display: DisplayTarget) -> some View {
        let scales = model.availableBuiltInScalePercents
        let currentScale = model.selectedBuiltInMode?.scalePercent ?? scales.first ?? 100
        let selectedIndex = scales.firstIndex(of: currentScale) ?? 0

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UI scale")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Choose how large the built-in display feels")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(currentScale)")
                        .font(.system(size: 35, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.secondary)
                }
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
            .disabled(scales.count <= 1)

            HStack {
                Text("MORE SPACE")
                Spacer()
                Text("LARGER UI")
            }
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(1)
            .foregroundStyle(.secondary)

            Text("The slider selects among resolutions macOS supports for this panel. Applying a scale changes the display resolution directly.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .panelStyle()
    }

    private func externalScalePicker(_ display: DisplayTarget) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UI scale")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Choose how large the interface feels")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(model.scalePercent)")
                        .font(.system(size: 35, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Slider(
                value: Binding(
                    get: { Double(model.scalePercent) },
                    set: { model.scalePercent = Int($0.rounded()) }
                ),
                in: 110...Double(display.maximumScalePercent),
                step: 5
            )
            .disabled(display.maximumScalePercent <= 110)

            HStack {
                Text("MORE SPACE")
                Spacer()
                Text("LARGER UI")
            }
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(1)
            .foregroundStyle(.secondary)

            Text("A higher percentage makes controls larger while keeping text rendered at 2× for sharper edges.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .panelStyle()
    }

    private func scalePreview(_ display: DisplayTarget) -> some View {
        HStack(spacing: 0) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text("Looks like \(model.selectedLogicalSize?.label ?? "—")")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(display.isBuiltIn
                    ? "Selected resolution from the built-in panel modes"
                    : "macOS workspace size at \(model.scalePercent)%")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 12)

            Spacer(minLength: 10)

            HStack(spacing: 5) {
                Image(systemName: display.isBuiltIn ? "display" : "checkmark.seal.fill")
                Text(display.isBuiltIn ? "macOS mode" : "2× HiDPI")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .panelStyle()
    }

    private var actionArea: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                statusIcon
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.system(size: 13, weight: .semibold))
                    Text(statusDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let status = model.latestStatus {
                Text(status.message)
                    .font(.system(size: 11))
                    .foregroundStyle(status.style == .success ? .green : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(action: primaryAction) {
                    HStack(spacing: 8) {
                        if model.isBusy {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: primaryIcon)
                        }
                        Text(primaryTitle)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(minWidth: 205)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || (model.selectedDisplayIsBuiltIn && !model.selectedModeLoaded))

                if !model.selectedDisplayIsBuiltIn && model.selectedOverrideInstalled {
                    Button("Update mode list") { model.installModes() }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy || model.selectedBackupExists && model.selectedForeignOverrideExists)
                }

                Spacer()

                Button("Displays Settings", action: model.openDisplaysSettings)
                    .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .panelStyle()
    }

    private func footer(_ display: DisplayTarget) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 5) {
                if display.isBuiltIn {
                    Text("Built-in resolutions use the modes macOS provides for this panel. No custom override or restart is needed.")
                } else {
                    Text("macOS loads display overrides at startup. Restart once after adding or removing modes.")
                    Text("The override is per display model, so identical screens use the same scale list.")
                }
                if !display.isBuiltIn && model.selectedOverrideInstalled {
                    Button("Remove DisplayScale modes…", role: .destructive) { showingRemoveConfirmation = true }
                        .buttonStyle(.bordered)
                        .padding(.top, 3)
                } else if !display.isBuiltIn && model.selectedForeignOverrideExists && !model.selectedBackupExists {
                    Text("An existing override will be copied aside before DisplayScale replaces it.")
                        .foregroundStyle(.orange)
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 3)
    }

    private var emptyState: some View {
        VStack(spacing: 17) {
            Image(systemName: "display.2")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.secondary)
                .padding(.top, 10)
            VStack(spacing: 6) {
                Text("No display found")
                    .font(.title3.weight(.semibold))
                Text("DisplayScale could not find an active screen. Refresh to try again.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 62)
        .panelStyle()
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
        if model.selectedDisplayIsBuiltIn {
            return Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(model.selectedModeLoaded ? .green : .orange)
        }
        let ready = model.selectedModeLoaded
        let color: Color = ready ? .green : (model.selectedOverrideInstalled ? .orange : .accentColor)
        return Image(systemName: ready ? "checkmark.circle.fill" : (model.selectedOverrideInstalled ? "clock.fill" : "sparkles"))
            .font(.system(size: 22))
            .foregroundStyle(color)
    }

    private var primaryTitle: String {
        if model.selectedDisplayIsBuiltIn { return "Set Resolution" }
        if model.selectedModeLoaded { return "Apply \(model.scalePercent)% scale" }
        if model.selectedOverrideInstalled { return "Refresh HiDPI modes" }
        return "Add HiDPI modes"
    }

    private var primaryIcon: String {
        if model.selectedDisplayIsBuiltIn { return "arrow.up.right.circle.fill" }
        return model.selectedModeLoaded ? "arrow.up.right.circle.fill" : "plus.circle.fill"
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

private struct ResolutionTile: View {
    let eyebrow: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                Text(eyebrow)
                    .foregroundStyle(.secondary)
                    .tracking(0.9)
            }
            .font(.system(size: 9, weight: .bold, design: .rounded))
            Text(value)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .panelStyle()
    }
}

private extension View {
    func panelStyle() -> some View {
        background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            }
    }
}
