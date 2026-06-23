import Foundation
import NaturalLanguage

/// Splits a document body into sentences (NLTokenizer) and groups those
/// sentences into token-bounded chunks for synthesis.
///
/// Two independent caps, whichever trips first:
///  - `maxTokensPerChunk`: stay clear of Kokoro's ~510-token ceiling (margin
///    left because our token estimate is approximate vs. Misaki's tokenizer).
///  - `maxSentencesPerChunk`: a coarse guard so a single run-on "sentence"
///    can't blow the per-call audio-length budget (gotcha §6.2).
///
/// Critically, this also exposes the **first-sentence fast path** (§6.3): the
/// playback layer synthesizes sentence 0 *alone* so audio starts within ~2s
/// instead of waiting for a whole chunk.
public struct Chunker {

    public struct Config {
        /// ~510 hard limit in Kokoro; we leave a generous margin.
        public var maxTokensPerChunk: Int
        public var maxSentencesPerChunk: Int

        public init(maxTokensPerChunk: Int = 360, maxSentencesPerChunk: Int = 6) {
            self.maxTokensPerChunk = maxTokensPerChunk
            self.maxSentencesPerChunk = maxSentencesPerChunk
        }

        public static let `default` = Config()
    }

    private let config: Config

    public init(config: Config = .default) {
        self.config = config
    }

    // MARK: Sentence segmentation

    /// Segments using NLTokenizer at sentence granularity. Whitespace-only
    /// fragments are dropped. Character offsets are preserved for the free-tier
    /// character cap mapping.
    public func sentences(in text: String) -> [Sentence] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var result: [Sentence] = []
        var index = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let raw = String(text[range])
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return true }
            let offset = text.distance(from: text.startIndex, to: range.lowerBound)
            result.append(Sentence(id: index, text: trimmed, characterOffset: offset))
            index += 1
            return true
        }
        return result
    }

    // MARK: Chunk grouping

    public func chunks(from sentences: [Sentence]) -> [TextChunk] {
        guard !sentences.isEmpty else { return [] }

        var chunks: [TextChunk] = []
        var current: [Sentence] = []
        var currentTokens = 0

        func flush() {
            guard !current.isEmpty else { return }
            chunks.append(TextChunk(id: chunks.count, sentences: current))
            current.removeAll(keepingCapacity: true)
            currentTokens = 0
        }

        for sentence in sentences {
            let tokens = Self.estimateTokenCount(sentence.text)

            // A single sentence longer than the cap still ships as its own
            // chunk — the per-call audio guard below keeps it bounded, and we
            // never want to silently drop text.
            if tokens >= config.maxTokensPerChunk {
                flush()
                chunks.append(TextChunk(id: chunks.count, sentences: [sentence]))
                continue
            }

            let wouldOverflowTokens = currentTokens + tokens > config.maxTokensPerChunk
            let wouldOverflowCount = current.count >= config.maxSentencesPerChunk
            if wouldOverflowTokens || wouldOverflowCount {
                flush()
            }
            current.append(sentence)
            currentTokens += tokens
        }
        flush()
        return chunks
    }

    /// Convenience: text → chunks in one call.
    public func chunk(_ text: String) -> [TextChunk] {
        chunks(from: sentences(in: text))
    }

    // MARK: Token estimation

    /// Kokoro's real token count comes from Misaki's phoneme tokenizer, which we
    /// can't cheaply run here. We approximate with a word + punctuation count
    /// scaled up, deliberately *over*-estimating so we keep margin below 510.
    /// This only needs to be monotonic and conservative, not exact.
    static func estimateTokenCount(_ text: String) -> Int {
        var words = 0
        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: .byWords
        ) { _, _, _, _ in words += 1 }
        // ~1.5 phoneme-tokens per word is a safe upper bound for English.
        return max(1, Int(Double(words) * 1.5) + 2)
    }
}
