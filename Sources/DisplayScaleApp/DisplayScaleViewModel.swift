import AppKit
import Combine
import CoreGraphics
import Foundation

@MainActor
final class DisplayScaleViewModel: ObservableObject {
    private let preferences = UserDefaults(suiteName: "com.bonfales.displayscale") ?? .standard
    @Published private(set) var displays: [DisplayTarget] = []
    @Published var selectedDisplayID: CGDirectDisplayID?
    @Published private(set) var selectedBuiltInModeID: String?
    @Published var scalePercent: Int {
        didSet { preferences.set(scalePercent, forKey: "preferredScalePercent") }
    }
    @Published private(set) var isBusy = false
    @Published var alert: UserAlert?
    @Published private(set) var latestStatus: StatusMessage?

    init() {
        let savedScale = preferences.object(forKey: "preferredScalePercent") as? Int
        let useSavedScale = preferences.object(forKey: "usePreferredScale") as? Bool ?? true
        _scalePercent = Published(initialValue: useSavedScale ? (savedScale ?? 150) : 150)
        refresh()
    }

    var selectedDisplay: DisplayTarget? {
        displays.first { $0.id == selectedDisplayID }
    }

    var selectedBuiltInMode: BuiltInDisplayMode? {
        selectedDisplay?.builtInMode(id: selectedBuiltInModeID)
    }

    var selectedDisplayIsBuiltIn: Bool {
        selectedDisplay?.isBuiltIn == true
    }

    var selectedLogicalSize: PixelSize? {
        if let selectedBuiltInMode { return selectedBuiltInMode.logicalSize }
        return selectedDisplay?.logicalSize(forPercent: scalePercent)
    }

    var selectedModeLoaded: Bool {
        guard let display = selectedDisplay else { return false }
        return DisplayModeManager.containsHiDPIMode(
            for: display,
            percent: scalePercent,
            builtInModeID: selectedBuiltInModeID
        )
    }

    var selectedOverrideInstalled: Bool {
        guard let display = selectedDisplay else { return false }
        return DisplayModeManager.ownsOverride(for: display)
    }

    var selectedForeignOverrideExists: Bool {
        guard let display = selectedDisplay else { return false }
        return DisplayModeManager.hasForeignOverride(for: display)
    }

    var selectedBackupExists: Bool {
        guard let display = selectedDisplay else { return false }
        return FileManager.default.fileExists(atPath: display.backupURL.path)
    }

    func refresh() {
        let previousSelection = selectedDisplayID
        displays = DisplayDiscovery.activeDisplays()
        if let previousSelection, displays.contains(where: { $0.id == previousSelection }) {
            selectedDisplayID = previousSelection
        } else {
            selectedDisplayID = displays.first?.id
        }
        if previousSelection != selectedDisplayID {
            selectedBuiltInModeID = nil
        }
        synchronizeScaleForSelectedDisplay()
    }

    func selectDisplay(_ identifier: CGDirectDisplayID?) {
        guard selectedDisplayID != identifier else { return }
        selectedDisplayID = identifier
        selectedBuiltInModeID = nil
        latestStatus = nil
        synchronizeScaleForSelectedDisplay()
    }

    private func synchronizeScaleForSelectedDisplay() {
        if let display = selectedDisplay {
            if display.isBuiltIn {
                if selectedBuiltInModeID == nil || display.builtInMode(id: selectedBuiltInModeID) == nil {
                    selectedBuiltInModeID = display.currentBuiltInModeID ?? display.builtInModes.first?.id
                }
            } else {
                selectedBuiltInModeID = nil
                scalePercent = min(max(scalePercent, display.minimumScalePercent), display.maximumScalePercent)
            }
        }
    }

    func selectBuiltInMode(_ identifier: String) {
        guard let display = selectedDisplay, display.isBuiltIn,
              display.builtInMode(id: identifier) != nil else { return }
        selectedBuiltInModeID = identifier
        latestStatus = nil
    }

    func installModes() {
        guard let display = selectedDisplay else { return }
        guard !display.isBuiltIn else {
            alert = UserAlert(title: "Built-in resolution", message: "Built-in display resolutions are available directly from macOS and do not need custom modes installed.")
            return
        }
        guard display.vendorID != 0, display.productID != 0 else {
            alert = UserAlert(title: "Display ID unavailable", message: "macOS did not report a usable vendor and product ID for this screen, so DisplayScale cannot create its per-model override.")
            return
        }
        if selectedForeignOverrideExists && selectedBackupExists {
            alert = UserAlert(title: "Existing override preserved", message: "A saved override already exists for this display model. DisplayScale left the current file untouched so it cannot replace the saved copy.")
            return
        }
        performOperation {
            try DisplayModeManager.installModes(for: display)
            return StatusMessage(
                title: "Modes added",
                message: "Restart your Mac once to load the new scale choices. Then reopen DisplayScale to apply any percentage.",
                style: .success
            )
        }
    }

    func applyScale() {
        guard let display = selectedDisplay else { return }
        let selectedPercent = scalePercent
        let selectedModeID = selectedBuiltInModeID
        performOperation {
            try DisplayModeManager.applyPermanently(
                to: display,
                percent: selectedPercent,
                builtInModeID: selectedModeID
            )
            return StatusMessage(
                title: display.isBuiltIn ? "Resolution applied" : "Scale applied",
                message: display.isBuiltIn
                    ? "The built-in display is now using \(display.builtInMode(id: selectedModeID)?.logicalSize.label ?? "the selected resolution"). macOS saved this as the display’s permanent setting."
                    : "The display is now using the \(selectedPercent)% HiDPI mode. macOS saved this as the display’s permanent setting.",
                style: .success
            )
        }
    }

    func removeModes() {
        guard let display = selectedDisplay else { return }
        guard !display.isBuiltIn else { return }
        performOperation {
            try DisplayModeManager.removeModes(for: display)
            return StatusMessage(
                title: "Custom modes removed",
                message: "Restart your Mac to return this display model to its original mode list.",
                style: .neutral
            )
        }
    }

    func openDisplaysSettings() {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") else { return }
        NSWorkspace.shared.open(appURL)
    }

    private func performOperation(_ operation: @escaping @Sendable () throws -> StatusMessage) {
        guard !isBusy else { return }
        isBusy = true
        latestStatus = nil
        Task { [weak self] in
            do {
                let status = try await Task.detached(priority: .userInitiated, operation: operation).value
                self?.latestStatus = status
                self?.refresh()
            } catch {
                self?.alert = UserAlert(title: "Couldn’t finish", message: error.localizedDescription)
            }
            self?.isBusy = false
        }
    }
}

struct UserAlert: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let message: String
}

struct StatusMessage: Sendable {
    enum Style: Sendable {
        case success
        case neutral
    }

    let title: String
    let message: String
    let style: Style
}
