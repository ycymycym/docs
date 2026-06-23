import SwiftUI
import ReaderCore

@main
struct OutloudApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(env)
                .environmentObject(env.library)
                .environmentObject(env.store)
                .environmentObject(env.playback)
                .task { await env.bootstrap() }
                // Deep link from the Share Extension: outloud://open?doc=<id>
                .onOpenURL { url in env.handleOpenURL(url) }
        }
    }
}
