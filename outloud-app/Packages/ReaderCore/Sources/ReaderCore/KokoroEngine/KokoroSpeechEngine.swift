import Foundation
import KokoroSwift
import MLX

/// ⚠️ INTEGRATION BOUNDARY — the ONLY file that imports KokoroSwift / MLX.
///
/// Verified against `mlalma/kokoro-ios` README (product `KokoroSwift`, 1.0.0):
///   • `KokoroTTS(modelPath: URL, g2p: G2POption)`           — init
///   • `generateAudio(voice: MLXArray, language: Language, text: String)` — synth
///   • G2P: `.misaki` (MisakiSwift, on-device, MIT-licensed — satisfies the
///     "no GPL G2P" requirement, gotcha §6.5)
///   • Output: 24 kHz mono float PCM
///   • Voice embeddings ("style vectors") are owned by the app, loaded as MLXArray.
///
/// The README warns signatures may drift, so EVERYTHING port-specific is
/// contained here. If `generateAudio`'s return type or the voice-loading call
/// differs in your pinned version, fix it here and nothing else changes.
public actor KokoroSpeechEngine: SpeechEngine {

    private let modelManager: ModelManager
    private let g2p: G2POption
    private var tts: KokoroTTS?

    /// Cache of decoded voice embeddings keyed by voice id, so we don't reload
    /// the style vector for every chunk.
    private var voiceCache: [String: MLXArray] = [:]

    /// KokoroSwift runs on MLX (Metal/GPU), not the ANE. The full-ANE CoreML
    /// plan's `ANECCompile() FAILED` problem (gotcha §6.1) therefore does not
    /// apply to this port; MLX selects the GPU automatically. We still surface a
    /// clean error path if Metal init fails on an unsupported simulator.
    public init(modelManager: ModelManager, g2p: G2POption = .misaki) {
        self.modelManager = modelManager
        self.g2p = g2p
    }

    public var isReady: Bool {
        get async { tts != nil }
    }

    public func prepare() async throws {
        if tts != nil { return }
        try await modelManager.ensureAvailable()

        let modelPath = modelManager.modelURL
        do {
            // Misaki G2P is bundled and on-device; no NLTK/Spacy dependency.
            self.tts = try KokoroTTS(modelPath: modelPath, g2p: g2p)
            Log.engine.info("KokoroTTS loaded (g2p=\(String(describing: self.g2p)))")
        } catch {
            Log.engine.error("KokoroTTS load failed: \(error.localizedDescription)")
            throw ReaderError.synthesisFailed(error.localizedDescription)
        }
    }

    public func synthesize(text: String, voice: Voice, speed: Float) async throws -> PCMAudio {
        if tts == nil { try await prepare() }
        guard let tts else { throw ReaderError.modelMissing }

        let embedding = try voiceEmbedding(for: voice)
        let language = Self.language(for: voice.language)

        do {
            // generateAudio returns the model's float PCM at 24 kHz. We normalize
            // to [Float] regardless of the concrete buffer type the port returns.
            let buffer = try tts.generateAudio(voice: embedding, language: language, text: text)
            var samples = Self.floatSamples(from: buffer)

            // Speed: KokoroSwift 1.0 does not expose a native speed knob, so we
            // report `.requiresPlaybackRate` and let the Playback layer time-
            // stretch via AVAudioUnitTimePitch (preserves pitch). We deliberately
            // do NOT resample here — that would change pitch and sound chipmunky.
            _ = speed
            if samples.isEmpty { samples = [] }
            return PCMAudio(samples: samples, sampleRate: 24_000)
        } catch {
            throw ReaderError.synthesisFailed(error.localizedDescription)
        }
    }

    public nonisolated static let speedHandling: SpeedHandling = .requiresPlaybackRate

    // MARK: Voice embeddings

    private func voiceEmbedding(for voice: Voice) throws -> MLXArray {
        if let cached = voiceCache[voice.id] { return cached }
        // Voices live in the downloaded `voices.bin` archive. The exact decode
        // call depends on how you pack them; the common pattern is a per-voice
        // [1, 256] (or [N, 256]) float tensor keyed by voice id.
        do {
            let array = try VoiceEmbeddingLoader.load(
                voiceID: voice.id,
                from: modelManager.voicesURL
            )
            voiceCache[voice.id] = array
            return array
        } catch {
            throw ReaderError.synthesisFailed("Couldn't load voice \(voice.displayName).")
        }
    }

    // MARK: Port type bridging

    private static func language(for lang: VoiceLanguage) -> Language {
        switch lang {
        case .americanEnglish: return .enUS
        case .britishEnglish:  return .enGB
        }
    }

    /// Normalizes whatever buffer type the port returns into `[Float]`. Adjust
    /// the single branch that matches your pinned version's return type.
    private static func floatSamples(from buffer: Any) -> [Float] {
        if let array = buffer as? MLXArray {
            return array.asArray(Float.self)
        }
        if let floats = buffer as? [Float] {
            return floats
        }
        if let data = buffer as? Data {
            return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        }
        assertionFailure("Unrecognized generateAudio return type — update floatSamples(from:)")
        return []
    }
}
