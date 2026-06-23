import Foundation
import AVFoundation
import MediaPlayer

/// Owns the AVAudioSession (background audio) plus lockscreen / Control Center
/// integration: MPNowPlayingInfoCenter for metadata and MPRemoteCommandCenter
/// for play/pause/skip. Brief acceptance: background playback with the screen
/// locked, and lockscreen controls must work.
final class NowPlayingController {

    struct Commands {
        var play: () -> Void
        var pause: () -> Void
        var toggle: () -> Void
        var skipForward: () -> Void
        var skipBackward: () -> Void
    }

    private let center = MPNowPlayingInfoCenter.default()
    private let remote = MPRemoteCommandCenter.shared()

    func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback keeps audio alive when the screen locks / app backgrounds.
            // Requires the "Audio, AirPlay, and Picture in Picture" background mode.
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            throw ReaderError.audioSessionFailed(error.localizedDescription)
        }
    }

    func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func wireRemoteCommands(_ commands: Commands) {
        remote.playCommand.addTarget { _ in commands.play(); return .success }
        remote.pauseCommand.addTarget { _ in commands.pause(); return .success }
        remote.togglePlayPauseCommand.addTarget { _ in commands.toggle(); return .success }

        // Map next/previous track to skip ±1 sentence (the product's nav unit).
        remote.nextTrackCommand.isEnabled = true
        remote.previousTrackCommand.isEnabled = true
        remote.nextTrackCommand.addTarget { _ in commands.skipForward(); return .success }
        remote.previousTrackCommand.addTarget { _ in commands.skipBackward(); return .success }
    }

    func update(title: String, detail: String?, rate: Float,
                elapsed: TimeInterval, duration: TimeInterval?) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: rate
        ]
        if let detail { info[MPMediaItemPropertyArtist] = detail }
        if let duration { info[MPMediaItemPropertyPlaybackDuration] = duration }
        center.nowPlayingInfo = info
    }

    func clear() {
        center.nowPlayingInfo = nil
    }
}
