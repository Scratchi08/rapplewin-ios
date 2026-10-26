import SwiftUI

@main
struct RAppleWinApp: App {
    @StateObject private var model = EmulatorModel()
    var body: some Scene {
        WindowGroup {
            EmulatorScreen(model: model)
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}
