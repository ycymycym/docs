import Foundation
import AVFoundation

/// Wraps AVAudioEngine + AVAudioPlayerNode to schedule 24 kHz mono Float PCM
/// buffers back-to-back for gapless playback, with pitch-preserving speed via
/// AVAudioUnitTimePitch (KokoroSwift 1.0 has no native speed knob).
///
/// Graph:  playerNode → timePitch → mainMixer → output
final class AudioScheduler {

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                       sampleRate: 24_000,
                                       channels: 1,
                                       interleaved: false)!

    /// Called on the main actor when a scheduled buffer finishes playing,
    /// carrying the sentence id it represented — drives highlight-free progress.
    var onSentenceFinished: (@Sendable (Int) -> Void)?

    private var isConfigured = false

    func configure() throws {
        guard !isConfigured else { return }
        engine.attach(player)
        engine.attach(timePitch)
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)
        engine.prepare()
        isConfigured = true
    }

    func start() throws {
        try configure()
        if !engine.isRunning {
            do { try engine.start() }
            catch { throw ReaderError.audioSessionFailed(error.localizedDescription) }
        }
        player.play()
    }

    func pause() { player.pause() }
    func resume() { player.play() }

    func stop() {
        player.stop()
        engine.stop()
    }

    /// 1.0 == natural. TimePitch rate is 1/32...32; we clamp to product range.
    func setSpeed(_ speed: Float) {
        timePitch.rate = max(0.5, min(2.0, speed))
    }

    /// Schedules a synthesized chunk for one sentence. The completion fires when
    /// that buffer has been *rendered*, which we use to advance progress.
    func schedule(_ audio: PCMAudio, sentenceID: Int) {
        guard !audio.samples.isEmpty,
              let buffer = Self.makeBuffer(from: audio, format: format) else {
            // Empty/whitespace sentence: report finished immediately so we don't stall.
            onSentenceFinished?(sentenceID)
            return
        }
        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            self?.onSentenceFinished?(sentenceID)
        }
    }

    /// Drops everything still queued (used on skip/seek so we can re-prime).
    func flush() {
        player.stop()   // clears scheduled buffers
        player.play()
    }

    private static func makeBuffer(from audio: PCMAudio,
                                   format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(audio.samples.count)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData else { return nil }
        buffer.frameLength = frames
        audio.samples.withUnsafeBufferPointer { src in
            channel[0].update(from: src.baseAddress!, count: audio.samples.count)
        }
        return buffer
    }
}
