import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: DisplayScaleViewModel
    @State private var showingRemoveConfirmation = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .underPageBackgroundColor)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

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
                }
                .padding(30)
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
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

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [.indigo, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "display.2")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)
            .shadow(color: .cyan.opacity(0.18), radius: 14, y: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text("DisplayScale")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .tracking(-0.5)
                Text("Add sharp HiDPI scaling to external displays")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: model.refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Refresh connected displays")
        }
    }

    private var displaySelector: some View {
        HStack(spacing: 12) {
            Image(systemName: "display")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.cyan)
                .frame(width: 42, height: 42)
                .background(.cyan.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text("DISPLAY")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text(model.selectedDisplay?.name ?? "External display")
                    .font(.system(size: 15, weight: .medium))
            }

            Spacer()

            if model.displays.count > 1 {
                Picker("Display", selection: $model.selectedDisplayID) {
                    ForEach(model.displays) { display in
                        Text(display.name).tag(Optional(display.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 250)
            } else {
                Text("EXTERNAL")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.cyan.opacity(0.1), in: Capsule())
            }
        }
        .padding(16)
        .panelStyle()
    }

    private func displaySummary(_ display: ExternalDisplay) -> some View {
        HStack(spacing: 14) {
            ResolutionTile(
                eyebrow: "NATIVE PANEL",
                value: display.nativeSize.label,
                detail: display.nativeResolutionSource,
                symbol: "viewfinder",
                tint: .cyan
            )
            ResolutionTile(
                eyebrow: "SCALE PREVIEW",
                value: (model.selectedLogicalSize.map { "\($0.label) UI" }) ?? "—",
                detail: "\(model.selectedLogicalSize.map { PixelSize(width: $0.width * 2, height: $0.height * 2).label } ?? "—") HiDPI render",
                symbol: "sparkles",
                tint: .indigo
            )
        }
    }

    private func scalePicker(_ display: ExternalDisplay) -> some View {
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
                .foregroundStyle(.white)
            }

            Slider(
                value: Binding(
                    get: { Double(model.scalePercent) },
                    set: { model.scalePercent = Int($0.rounded()) }
                ),
                in: 110...Double(display.maximumScalePercent),
                step: 5
            )
            .tint(.cyan)
            .disabled(display.maximumScalePercent <= 110)

            HStack {
                Text("MORE SPACE")
                Spacer()
                Text("LARGER UI")
            }
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(1)
            .foregroundStyle(.tertiary)

            Text("A higher percentage makes controls larger while keeping text rendered at 2× for sharper edges.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .panelStyle()
    }

    private func scalePreview(_ display: ExternalDisplay) -> some View {
        HStack(spacing: 0) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.mint)
                .frame(width: 42, height: 42)
                .background(.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("Looks like \(model.selectedLogicalSize?.label ?? "—")")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("macOS workspace size at \(model.scalePercent)%")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 12)

            Spacer(minLength: 10)

            HStack(spacing: 5) {
                Image(systemName: "checkmark.seal.fill")
                Text("2× HiDPI")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.mint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.mint.opacity(0.1), in: Capsule())
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
                    .foregroundStyle(status.style == .success ? .mint : .secondary)
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
                .tint(.cyan)
                .disabled(model.isBusy)

                if model.selectedOverrideInstalled {
                    Button("Update mode list") { model.installModes() }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy || model.selectedBackupExists && model.selectedForeignOverrideExists)
                }

                Spacer()

                Button("Displays Settings", action: model.openDisplaysSettings)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .panelStyle()
    }

    private func footer(_ display: ExternalDisplay) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 5) {
                Text("macOS loads display overrides at startup. Restart once after adding or removing modes.")
                Text("The override is per display model, so identical screens use the same scale list.")
                if model.selectedOverrideInstalled {
                    Button("Remove DisplayScale modes…") { showingRemoveConfirmation = true }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red.opacity(0.85))
                        .padding(.top, 3)
                } else if model.selectedForeignOverrideExists && !model.selectedBackupExists {
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
                .font(.system(size: 45, weight: .light))
                .foregroundStyle(.cyan.opacity(0.8))
                .padding(.top, 10)
            VStack(spacing: 6) {
                Text("Connect an external display")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text("DisplayScale detects connected screens and reads their native resolution automatically.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            Button("Refresh displays", action: model.refresh)
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 62)
        .panelStyle()
    }

    private var statusTitle: String {
        if model.selectedModeLoaded { return "HiDPI scale is ready" }
        if model.selectedOverrideInstalled { return "Restart needed to load this scale" }
        if model.selectedForeignOverrideExists { return "An existing display override was found" }
        return "Custom HiDPI modes are not installed"
    }

    private var statusDescription: String {
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
        let color: Color = ready ? .mint : (model.selectedOverrideInstalled ? .orange : .cyan)
        return Image(systemName: ready ? "checkmark.circle.fill" : (model.selectedOverrideInstalled ? "clock.fill" : "sparkles"))
            .font(.system(size: 22))
            .foregroundStyle(color)
    }

    private var primaryTitle: String {
        if model.selectedModeLoaded { return "Apply \(model.scalePercent)% scale" }
        if model.selectedOverrideInstalled { return "Refresh HiDPI modes" }
        return "Add HiDPI modes"
    }

    private var primaryIcon: String {
        model.selectedModeLoaded ? "arrow.up.right.circle.fill" : "plus.circle.fill"
    }

    private func primaryAction() {
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
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.07), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
    }
}
