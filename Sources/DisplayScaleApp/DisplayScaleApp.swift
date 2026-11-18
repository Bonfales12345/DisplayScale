import SwiftUI

@main
struct DisplayScaleApp: App {
    @StateObject private var model = DisplayScaleViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 660, minHeight: 560)
        }
        .windowResizability(.contentSize)
    }
}
