import SwiftUI

@main
struct dshApp: App {
    @ObservedObject private var theme = ThemeStateHolder.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(theme)
                .onOpenURL { AppModel.shared.handleIncomingURL($0) }
        }
    }
}
