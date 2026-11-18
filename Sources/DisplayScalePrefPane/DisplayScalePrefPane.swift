import AppKit
import PreferencePanes
import SwiftUI

@MainActor
@objc(DisplayScalePrefPane)
final class DisplayScalePrefPane: NSPreferencePane {
    private var model: DisplayScaleViewModel?

    override func loadMainView() -> NSView {
        let model = DisplayScaleViewModel()
        let content = ContentView()
            .environmentObject(model)
            .frame(minWidth: 660, minHeight: 560)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: 720, height: 600)
        hostingView.autoresizingMask = [.width, .height]

        self.model = model
        self.mainView = hostingView
        return hostingView
    }

    override func willSelect() {
        model?.refresh()
    }
}
