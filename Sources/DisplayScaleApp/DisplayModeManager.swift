import AppKit
import CoreGraphics
import Foundation

enum DisplayScaleError: LocalizedError {
    case displayNotFound
    case modeNotLoaded
    case configurationFailed(CGError)
    case plistCreationFailed
    case privilegeToolFailed(String)

    var errorDescription: String? {
        switch self {
        case .displayNotFound:
            return "That display is no longer connected. Refresh the display list and try again."
        case .modeNotLoaded:
            return "macOS has not loaded this scale yet. Install the modes, restart your Mac, then try again."
        case .configurationFailed(let code):
            return "macOS could not apply this display mode (error \(code.rawValue)). Quit full-screen apps and try again."
        case .plistCreationFailed:
            return "DisplayScale could not prepare the display mode file."
        case .privilegeToolFailed(let details):
            return details.isEmpty ? "The administrator operation did not finish." : details
        }
    }
}

enum DisplayModeManager {
    static func containsHiDPIMode(for display: ExternalDisplay, percent: Int) -> Bool {
        guard let target = matchingMode(for: display, percent: percent) else { return false }
        return target.isUsableForDesktopGUI()
    }

    static func applyPermanently(to display: ExternalDisplay, percent: Int) throws {
        guard CGDisplayIsActive(display.id) != 0 else { throw DisplayScaleError.displayNotFound }
        guard let mode = matchingMode(for: display, percent: percent) else {
            throw DisplayScaleError.modeNotLoaded
        }

        var configuration: CGDisplayConfigRef?
        let beginResult = CGBeginDisplayConfiguration(&configuration)
        guard beginResult == .success, let configuration else {
            throw DisplayScaleError.configurationFailed(beginResult)
        }

        let configureResult = CGConfigureDisplayWithDisplayMode(configuration, display.id, mode, nil)
        guard configureResult == .success else {
            CGCancelDisplayConfiguration(configuration)
            throw DisplayScaleError.configurationFailed(configureResult)
        }

        let completeResult = CGCompleteDisplayConfiguration(configuration, .permanently)
        guard completeResult == .success else {
            throw DisplayScaleError.configurationFailed(completeResult)
        }
    }

    static func installModes(for display: ExternalDisplay) throws {
        let plist = try overridePlist(for: display)
        let stagingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DisplayScale-\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: stagingURL) }
        try plist.write(to: stagingURL, options: .atomic)

        let target = display.overrideURL.path
        let backup = display.backupURL.path
        let staging = stagingURL.path
        let command = """
        /bin/mkdir -p \(shellQuote(URL(fileURLWithPath: target).deletingLastPathComponent().path)) && \
        if [ -e \(shellQuote(target)) ]; then \
          if ! /usr/libexec/PlistBuddy -c 'Print :DisplayProductName' \(shellQuote(target)) 2>/dev/null | /usr/bin/grep -q '^DisplayScale'; then \
            if [ -e \(shellQuote(backup)) ]; then /bin/echo 'A saved display override already exists; refusing to replace another file.' >&2; exit 3; fi; \
            /bin/cp -p \(shellQuote(target)) \(shellQuote(backup)) || exit 4; \
          fi; \
        fi && \
        /usr/bin/install -o root -g wheel -m 644 \(shellQuote(staging)) \(shellQuote(target)) && \
        /usr/bin/defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool YES
        """
        try runAsAdministrator(command)
    }

    static func removeModes(for display: ExternalDisplay) throws {
        let target = display.overrideURL.path
        let backup = display.backupURL.path
        let command = """
        if [ ! -e \(shellQuote(target)) ] || ! /usr/libexec/PlistBuddy -c 'Print :DisplayProductName' \(shellQuote(target)) 2>/dev/null | /usr/bin/grep -q '^DisplayScale'; then \
          /bin/echo 'DisplayScale did not create the current override; nothing was removed.' >&2; exit 5; \
        fi && \
        if [ -e \(shellQuote(backup)) ]; then /bin/mv \(shellQuote(backup)) \(shellQuote(target)); else /bin/rm -f \(shellQuote(target)); fi
        """
        try runAsAdministrator(command)
    }

    static func ownsOverride(for display: ExternalDisplay) -> Bool {
        guard let data = try? Data(contentsOf: display.overrideURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let name = plist["DisplayProductName"] as? String else { return false }
        return name.hasPrefix("DisplayScale")
    }

    static func hasForeignOverride(for display: ExternalDisplay) -> Bool {
        FileManager.default.fileExists(atPath: display.overrideURL.path) && !ownsOverride(for: display)
    }

    private static func matchingMode(for display: ExternalDisplay, percent: Int) -> CGDisplayMode? {
        let logical = display.logicalSize(forPercent: percent)
        let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
        let modes = (CGDisplayCopyAllDisplayModes(display.id, options) as? [CGDisplayMode]) ?? []
        return modes.first { mode in
            mode.width == logical.width &&
            mode.height == logical.height &&
            mode.pixelWidth == logical.width * 2 &&
            mode.pixelHeight == logical.height * 2 &&
            mode.isUsableForDesktopGUI()
        }
    }

    private static func overridePlist(for display: ExternalDisplay) throws -> Data {
        var resolutionData: [Data] = []
        for percent in display.availableScalePercents {
            let logical = display.logicalSize(forPercent: percent)
            let renderWidth = UInt32(logical.width * 2)
            let renderHeight = UInt32(logical.height * 2)
            resolutionData.append(bigEndianData([renderWidth, renderHeight, 9, 0x0020_0000]))
            resolutionData.append(bigEndianData([renderWidth, renderHeight]))
            resolutionData.append(bigEndianData([UInt32(logical.width), UInt32(logical.height)]))
        }
        guard !resolutionData.isEmpty else { throw DisplayScaleError.plistCreationFailed }

        let plist: [String: Any] = [
            "DisplayVendorID": Int(display.vendorID),
            "DisplayProductID": Int(display.productID),
            "DisplayProductName": "DisplayScale (\(display.name))",
            "scale-resolutions": resolutionData
        ]
        do {
            return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        } catch {
            throw DisplayScaleError.plistCreationFailed
        }
    }

    private static func bigEndianData(_ values: [UInt32]) -> Data {
        var bytes = Data(capacity: values.count * 4)
        for value in values {
            bytes.append(UInt8((value >> 24) & 0xFF))
            bytes.append(UInt8((value >> 16) & 0xFF))
            bytes.append(UInt8((value >> 8) & 0xFF))
            bytes.append(UInt8(value & 0xFF))
        }
        return bytes
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func runAsAdministrator(_ command: String) throws {
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "do shell script \"\(escapedCommand)\" with administrator privileges"]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let details = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw DisplayScaleError.privilegeToolFailed(details)
        }
    }
}
