import Foundation

/// Local-only persistence for the recent-documents library and resume points.
/// One JSON file in Application Support. No cloud, no account.
///
/// Also the pickup point for documents handed off by the Share Extension via
/// the App Group inbox.
@MainActor
public final class LibraryStore: ObservableObject {

    @Published public private(set) var documents: [ReaderDocument] = []

    private let fileURL: URL
    private let maxDocuments = 50

    public init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("library.json")
        load()
    }

    // MARK: CRUD

    public func upsert(_ doc: ReaderDocument) {
        if let i = documents.firstIndex(where: { $0.id == doc.id }) {
            documents[i] = doc
        } else {
            documents.insert(doc, at: 0)
        }
        trimAndSort()
        save()
    }

    public func updateResume(documentID: String, sentenceIndex: Int) {
        guard let i = documents.firstIndex(where: { $0.id == documentID }) else { return }
        documents[i].resumeSentenceIndex = sentenceIndex
        documents[i].lastOpenedAt = .now
        save()
    }

    public func delete(_ id: String) {
        documents.removeAll { $0.id == id }
        save()
    }

    public func document(id: String) -> ReaderDocument? {
        documents.first(where: { $0.id == id })
    }

    // MARK: Share Extension inbox

    /// Picks up a document the extension wrote to the App Group inbox and folds
    /// it into the local library. Returns the new document, ready to play.
    public func importFromInbox(documentID: String) -> ReaderDocument? {
        guard let inbox = AppGroup.inboxURL else { return nil }
        let url = inbox.appendingPathComponent("\(documentID).json")
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(InboxPayload.self, from: data) else {
            return nil
        }
        let doc = ReaderDocument(
            id: documentID,
            title: payload.title,
            sourceKind: payload.sourceKind,
            body: payload.body
        )
        upsert(doc)
        try? FileManager.default.removeItem(at: url)  // consume it
        return doc
    }

    // MARK: Persistence

    private func trimAndSort() {
        documents.sort { $0.lastOpenedAt > $1.lastOpenedAt }
        if documents.count > maxDocuments {
            documents = Array(documents.prefix(maxDocuments))
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let docs = try? JSONDecoder().decode([ReaderDocument].self, from: data) else {
            return
        }
        documents = docs
        trimAndSort()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(documents) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// What the Share Extension writes into the App Group inbox. The extension does
/// extraction only (no synthesis — brief §4), so it ships plain text.
public struct InboxPayload: Codable, Sendable {
    public let title: String
    public let body: String
    public let sourceKind: ReaderDocument.SourceKind

    public init(title: String, body: String, sourceKind: ReaderDocument.SourceKind) {
        self.title = title
        self.body = body
        self.sourceKind = sourceKind
    }
}
