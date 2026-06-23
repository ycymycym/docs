import SwiftUI
import ReaderCore

struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var playback: PlaybackEngine

    var body: some View {
        NavigationStack {
            LibraryView()
                .navigationDestination(isPresented: Binding(
                    get: { env.route == .nowPlaying },
                    set: { if !$0 { env.route = .library } }
                )) {
                    NowPlayingView()
                }
        }
        .overlay {
            if env.isImporting {
                ProgressView("Reading document…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("Couldn't open", isPresented: Binding(
            get: { env.importError != nil },
            set: { if !$0 { env.importError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(env.importError ?? "")
        }
    }
}
