import Foundation

/// A single sentence as segmented by NLTokenizer. Sentences are the unit of
/// navigation (skip ±1 sentence) and of progress/resume.
public struct Sentence: Identifiable, Equatable, Sendable {
    public let id: Int            // global index within the document, 0-based
    public let text: String
    /// Character offset of this sentence's start within the full document body.
    /// Used to map "first 3000 characters" free-tier cap onto a sentence index.
    public let characterOffset: Int

    public init(id: Int, text: String, characterOffset: Int) {
        self.id = id
        self.text = text
        self.characterOffset = characterOffset
    }
}

/// A synthesis unit: a contiguous run of sentences grouped to stay under
/// Kokoro's ~510-token limit *and* under the per-call audio-length cap
/// (gotcha §6.2 — long calls get watchdog-killed on 4GB devices). One chunk ==
/// one `generateAudio` call.
public struct TextChunk: Identifiable, Equatable, Sendable {
    public let id: Int            // chunk index within the document
    public let sentences: [Sentence]

    public init(id: Int, sentences: [Sentence]) {
        self.id = id
        self.sentences = sentences
    }

    public var text: String { sentences.map(\.text).joined(separator: " ") }
    public var firstSentenceID: Int? { sentences.first?.id }
    public var lastSentenceID: Int? { sentences.last?.id }
}
