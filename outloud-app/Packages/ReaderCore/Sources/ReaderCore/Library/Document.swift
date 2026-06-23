import Foundation

/// A document in the user's library. Stored locally only — no cloud, ever
/// (brief §2). The full body text is persisted so airplane-mode replay works
/// after the one-time model download.
public struct ReaderDocument: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public var title: String
    public var sourceKind: SourceKind
    public var body: String
    /// Resume point — the sentence index to start from next time.
    public var resumeSentenceIndex: Int
    public var voiceID: String
    public var createdAt: Date
    public var lastOpenedAt: Date

    public enum SourceKind: String, Codable, Sendable {
        case pdf, web, plainText
    }

    public init(id: String = UUID().uuidString,
                title: String,
                sourceKind: SourceKind,
                body: String,
                resumeSentenceIndex: Int = 0,
                voiceID: String = VoiceCatalog.default.id,
                createdAt: Date = .now,
                lastOpenedAt: Date = .now) {
        self.id = id
        self.title = title
        self.sourceKind = sourceKind
        self.body = body
        self.resumeSentenceIndex = resumeSentenceIndex
        self.voiceID = voiceID
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
    }
}
