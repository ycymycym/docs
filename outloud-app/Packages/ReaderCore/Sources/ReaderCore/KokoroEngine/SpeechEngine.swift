import Foundation

/// PCM audio produced by the engine. Kokoro outputs 24 kHz mono float samples;
/// the playback layer turns these into AVAudioPCMBuffers.
public struct PCMAudio: Sendable, Equatable {
    public let samples: [Float]      // mono, normalized -1...1
    public let sampleRate: Double    // 24_000 for Kokoro

    public init(samples: [Float], sampleRate: Double = 24_000) {
        self.samples = samples
        self.sampleRate = sampleRate
    }

    public var duration: TimeInterval {
        sampleRate > 0 ? Double(samples.count) / sampleRate : 0
    }

    public static let silence = PCMAudio(samples: [], sampleRate: 24_000)
}

/// The boundary every other module talks to. The concrete Kokoro integration
/// lives behind this so (a) the rest of the app never imports KokoroSwift, and
/// (b) tests can inject a fake engine.
///
/// `synthesize` takes a *single chunk's* text. Callers must keep chunks short
/// (target <15s of audio per call) — see gotcha §6.2.
public protocol SpeechEngine: Sendable {
    /// True once the model is loaded and ready to synthesize.
    var isReady: Bool { get async }

    /// Load (and if necessary download) the model and prepare the engine.
    /// Idempotent — safe to call on every app launch.
    func prepare() async throws

    /// Synthesize one chunk of text in the given voice at the given speed.
    /// - Parameter speed: 1.0 == natural. Kokoro's native speed parameter is
    ///   preferred for naturalness; if the port doesn't expose it the playback
    ///   layer falls back to AVAudioUnitTimePitch.
    /// - Returns: 24 kHz mono PCM.
    func synthesize(text: String, voice: Voice, speed: Float) async throws -> PCMAudio
}

/// Does the engine apply `speed` itself, or must playback rate-shift? Lets the
/// Playback layer decide whether to wire up AVAudioUnitTimePitch.
public enum SpeedHandling: Sendable {
    case nativeInEngine        // engine bakes speed into the PCM
    case requiresPlaybackRate  // engine ignores speed; playback must time-stretch
}
