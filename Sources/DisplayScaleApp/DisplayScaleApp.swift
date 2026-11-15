import SwiftUI

@main
struct DisplayScaleApp: App {
    @StateObject private var model = DisplayScaleViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 700, minHeight: 680)
        }
        .windowResizability(.contentSize)
    }
}
