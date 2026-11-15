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
            .frame(minWidth: 700, minHeight: 680)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: 760, height: 720)
        hostingView.autoresizingMask = [.width, .height]

        self.model = model
        self.mainView = hostingView
        return hostingView
    }

    override func willSelect() {
        model?.refresh()
    }
}
