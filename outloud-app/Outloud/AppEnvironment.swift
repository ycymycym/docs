import SwiftUI
import Combine
import ReaderCore

/// Composition root. Owns the long-lived services and wires the pipeline:
///   TextExtraction → TranslationStage(passthrough) → Chunking → Playback,
/// with Paywall + Library + Model around it.
@MainActor
final class AppEnvironment: ObservableObject {

    let library = LibraryStore()
    let store = StoreManager()
    let modelManager = ModelManager()

    let engine: SpeechEngine
    let playback: PlaybackEngine

    private let extractor = TextExtractor()
    private let translation: TranslationStage = PassthroughTranslationStage()

    /// UI surfaces driven by the environment.
    @Published var route: Route = .library
    @Published var isImporting = false
    @Published var importError: String?
    @Published var modelState: ModelManager.State = .notDownloaded

    enum Route: Equatable { case library, nowPlaying }

    init() {
        let engine = KokoroSpeechEngine(modelManager: modelManager)
        self.engine = engine
        self.playback = PlaybackEngine(
            engine: engine,
            library: library,
            isUnlocked: { false }  // replaced in bootstrap once store is wired
        )
    }

    func bootstrap() async {
        // Wire the live entitlement into the playback gate.
        let store = self.store
        playback.updateUnlockProvider { store.isUnlocked }

        await store.load()
        await modelManager.observe { [weak self] state in
            Task { @MainActor in self?.modelState = state }
        }
    }

    // MARK: Entry points

    /// Web fetches are deferred by the extension (which lacks the budget for
    /// WKWebView). It marks the body so the host re-extracts the article here.
    private static let deferredWebMarker = "@@OUTLOUD_FETCH_URL@@"

    /// Deep link handoff from the Share Extension.
    func handleOpenURL(_ url: URL) {
        guard let docID = AppGroup.documentID(from: url) else { return }
        guard let doc = library.importFromInbox(documentID: docID) ?? library.document(id: docID) else { return }

        // Deferred web article: the extension only forwarded the URL.
        if doc.body.hasPrefix(Self.deferredWebMarker),
           let articleURL = URL(string: String(doc.body.dropFirst(Self.deferredWebMarker.count))) {
            library.delete(doc.id)
            importURL(articleURL)
            return
        }
        startPlayback(doc)
    }

    /// In-app PDF import (UIDocumentPicker).
    func importPDF(at url: URL) {
        runImport { try await self.extractor.extract(from: .pdf(url)) }
    }

    /// In-app "paste a link".
    func importURL(_ url: URL) {
        runImport { try await self.extractor.extract(from: .webURL(url)) }
    }

    /// In-app "paste text".
    func importText(_ text: String, title: String?) {
        runImport { try await self.extractor.extract(from: .plainText(text, title: title ?? "")) }
    }

    func openExisting(_ doc: ReaderDocument) {
        startPlayback(doc)
    }

    // MARK: Internals

    private func runImport(_ work: @escaping () async throws -> TextExtractor.Output) {
        isImporting = true
        importError = nil
        Task {
            do {
                let out = try await work()
                // TranslationStage seam (passthrough in v1).
                let translated = try await translation.process(out.body, progress: { _ in })
                let doc = ReaderDocument(
                    title: out.title,
                    sourceKind: out.sourceKind,
                    body: translated.text
                )
                library.upsert(doc)
                isImporting = false
                startPlayback(doc)
            } catch {
                isImporting = false
                importError = (error as? ReaderError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func startPlayback(_ doc: ReaderDocument) {
        route = .nowPlaying
        playback.load(document: doc)
    }
}
