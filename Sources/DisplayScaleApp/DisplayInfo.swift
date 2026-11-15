import CoreGraphics
import Foundation
import IOKit
import IOKit.graphics
import AppKit

struct PixelSize: Equatable, Hashable, Sendable {
    let width: Int
    let height: Int

    var area: Int { width * height }

    var label: String { "\(width.formatted()) × \(height.formatted())" }
}

struct ExternalDisplay: Identifiable, Equatable, Sendable {
    let id: CGDirectDisplayID
    let name: String
    let vendorID: UInt32
    let productID: UInt32
    let nativeSize: PixelSize
    let nativeResolutionSource: String

    var vendorHex: String { String(vendorID, radix: 16) }
    var productHex: String { String(productID, radix: 16) }

    func logicalSize(forPercent percent: Int) -> PixelSize {
        func evenRounded(_ value: Double) -> Int {
            max(2, Int((value / 2).rounded()) * 2)
        }
        let ratio = Double(percent) / 100
        return PixelSize(
            width: evenRounded(Double(nativeSize.width) / ratio),
            height: evenRounded(Double(nativeSize.height) / ratio)
        )
    }

    var maximumScalePercent: Int {
        let widthLimit = nativeSize.width * 100 / 480
        let heightLimit = nativeSize.height * 100 / 270
        let raw = min(250, min(widthLimit, heightLimit))
        return max(110, (raw / 5) * 5)
    }

    var availableScalePercents: [Int] {
        Array(stride(from: 110, through: maximumScalePercent, by: 5))
    }

    var overrideURL: URL {
        URL(fileURLWithPath: "/Library/Displays/Contents/Resources/Overrides")
            .appendingPathComponent("DisplayVendorID-\(vendorHex)", isDirectory: true)
            .appendingPathComponent("DisplayProductID-\(productHex)")
    }

    var backupURL: URL {
        overrideURL.appendingPathExtension("displayscale-backup")
    }
}

enum DisplayDiscovery {
    static func externalDisplays() -> [ExternalDisplay] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = Array(repeating: CGDirectDisplayID(), count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }

        let serviceInfo = connectedDisplayInfo()
        let screensByID = Dictionary(uniqueKeysWithValues: NSScreen.screens.compactMap { screen -> (CGDirectDisplayID, NSScreen)? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            return (number.uint32Value, screen)
        })

        return ids.prefix(Int(count)).compactMap { displayID in
            guard CGDisplayIsBuiltin(displayID) == 0 else { return nil }
            let vendorID = CGDisplayVendorNumber(displayID)
            let productID = CGDisplayModelNumber(displayID)
            let info = serviceInfo.first { $0.vendorID == vendorID && $0.productID == productID }
            let modes = (CGDisplayCopyAllDisplayModes(displayID, [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary)
                as? [CGDisplayMode]) ?? []
            let native = info?.preferredMode ?? largestOneToOneMode(in: modes) ?? PixelSize(
                width: Int(CGDisplayPixelsWide(displayID)),
                height: Int(CGDisplayPixelsHigh(displayID))
            )
            guard native.width > 0, native.height > 0 else { return nil }
            let name = screensByID[displayID]?.localizedName ?? info?.name ?? "External Display"
            let source = info?.preferredMode != nil ? "EDID preferred timing" : "macOS display mode"
            return ExternalDisplay(
                id: displayID,
                name: name,
                vendorID: vendorID,
                productID: productID,
                nativeSize: native,
                nativeResolutionSource: source
            )
        }
    }

    private struct IODisplayInfo {
        let vendorID: UInt32
        let productID: UInt32
        let name: String?
        let preferredMode: PixelSize?
    }

    private static func connectedDisplayInfo() -> [IODisplayInfo] {
        guard let matching = IOServiceMatching("IODisplayConnect") else { return [] }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var results: [IODisplayInfo] = []
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }
            guard let rawInfo = IODisplayCreateInfoDictionary(service, IOOptionBits(kIODisplayOnlyPreferredName))?.takeRetainedValue() else {
                continue
            }
            let info = rawInfo as NSDictionary
            let vendor = (info[kDisplayVendorID] as? NSNumber)?.uint32Value
                ?? (info["LegacyManufacturerID"] as? NSNumber)?.uint32Value
            let product = (info[kDisplayProductID] as? NSNumber)?.uint32Value
                ?? (info["ProductID"] as? NSNumber)?.uint32Value
            guard let vendor, let product else { continue }
            let nameValue = info[kDisplayProductName] as? [String: String]
            let name = nameValue?.values.first ?? (info[kDisplayProductName] as? String)
            let edid = (info[kIODisplayEDIDKey] as? Data)
                ?? (info[kIODisplayEDIDOriginalKey] as? Data)
            results.append(IODisplayInfo(
                vendorID: vendor,
                productID: product,
                name: name,
                preferredMode: edid.flatMap(preferredDetailedTiming)
            ))
        }
        return results
    }

    private static func preferredDetailedTiming(_ data: Data) -> PixelSize? {
        let bytes = [UInt8](data)
        guard bytes.count >= 126 else { return nil }
        for offset in stride(from: 54, through: 108, by: 18) {
            let pixelClock = UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
            guard pixelClock != 0 else { continue }
            let width = Int(bytes[offset + 2]) | (Int(bytes[offset + 4] & 0xF0) << 4)
            let height = Int(bytes[offset + 5]) | (Int(bytes[offset + 7] & 0xF0) << 4)
            if width > 0, height > 0 { return PixelSize(width: width, height: height) }
        }
        return nil
    }

    private static func largestOneToOneMode(in modes: [CGDisplayMode]) -> PixelSize? {
        modes
            .filter { $0.isUsableForDesktopGUI() }
            .compactMap { mode -> PixelSize? in
                let width = mode.width
                let height = mode.height
                let pixelWidth = mode.pixelWidth
                let pixelHeight = mode.pixelHeight
                guard width == pixelWidth, height == pixelHeight else { return nil }
                return PixelSize(width: width, height: height)
            }
            .max { $0.area < $1.area }
    }
}
