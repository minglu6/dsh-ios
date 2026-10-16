import SwiftUI
import UIKit

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        TerminalTypeface.registerBundledFont()
        ConnectionKeeper.shared.registerBackgroundTasks()
        return true
    }
}

@main
struct dshApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var theme = ThemeStateHolder.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(theme)
                .onOpenURL { AppModel.shared.handleIncomingURL($0) }
                .onAppear { ConnectionKeeper.shared.start() }
        }
    }
}
