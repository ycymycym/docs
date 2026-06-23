import Foundation
import MLX

/// Loads a single voice's style embedding out of the packed `voices.bin`.
///
/// Kokoro voice embeddings are small float tensors (one "style vector" per
/// voice). How they're packed is a *you* decision made when you build the
/// asset bundle; this loader assumes the simplest robust layout:
///
///   voices.bin = a `.safetensors` / `.npz`-style archive keyed by voice id.
///
/// MLX ships loaders for both. If you instead concatenate raw float32 blocks,
/// replace the body with an offset lookup. Either way the rest of the engine
/// only sees an `MLXArray`.
enum VoiceEmbeddingLoader {

    /// In-process cache of the whole archive so we parse it at most once.
    private static var archive: [String: MLXArray]?
    private static let lock = NSLock()

    static func load(voiceID: String, from url: URL) throws -> MLXArray {
        lock.lock(); defer { lock.unlock() }

        if archive == nil {
            archive = try MLX.loadArrays(url: url)   // safetensors/npz → [name: MLXArray]
        }
        guard let array = archive?[voiceID] else {
            throw ReaderError.synthesisFailed("Voice \(voiceID) not found in bundle.")
        }
        return array
    }
}
