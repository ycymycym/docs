import UIKit
import UniformTypeIdentifiers
import ReaderCore

/// Share Extension entry point.
///
/// Hard rule (brief §4/§6.6): **no Kokoro synthesis here** — extensions get a
/// tight (~120MB) memory budget. This only extracts text, writes an
/// InboxPayload into the App Group container, and deep-links the host app,
/// which does all synthesis + playback.
final class ShareViewController: UIViewController {

    private let extractor = TextExtractor()

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedItem()
    }

    private func handleSharedItem() {
        guard let item = (extensionContext?.inputItems.first as? NSExtensionItem),
              let provider = item.attachments?.first else {
            return finish(error: ReaderError.emptyDocument)
        }

        Task {
            do {
                let output = try await extract(from: provider)
                let id = UUID().uuidString
                try write(output, id: id)
                openHostApp(documentID: id)
            } catch {
                finish(error: error)
            }
        }
    }

    // MARK: Type dispatch

    private func extract(from provider: NSItemProvider) async throws -> TextExtractor.Output {
        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            let url = try await loadFileURL(provider, type: .pdf)
            return try await extractor.extract(from: .pdf(url))
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            let url = try await loadURL(provider)
            // Web extraction needs WKWebView (main-thread, heavier) — defer it to
            // the host app. The extension just forwards the URL as a "to-fetch"
            // marker so it stays within budget.
            return TextExtractor.Output(title: url.host ?? "Article",
                                        body: "@@OUTLOUD_FETCH_URL@@" + url.absoluteString,
                                        sourceKind: .web)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            let text = try await loadText(provider)
            return try await extractor.extract(from: .plainText(text, title: ""))
        }
        throw ReaderError.unsupportedType("unknown")
    }

    // MARK: Item loading helpers

    private func loadFileURL(_ provider: NSItemProvider, type: UTType) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                if let error { cont.resume(throwing: error); return }
                guard let url else { cont.resume(throwing: ReaderError.extractionFailed("No file.")); return }
                // Copy into a temp location we control before the URL is invalidated.
                let temp = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension)
                do { try FileManager.default.copyItem(at: url, to: temp); cont.resume(returning: temp) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    private func loadURL(_ provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, error in
                if let error { cont.resume(throwing: error); return }
                if let url = item as? URL { cont.resume(returning: url) }
                else { cont.resume(throwing: ReaderError.extractionFailed("No URL.")) }
            }
        }
    }

    private func loadText(_ provider: NSItemProvider) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, error in
                if let error { cont.resume(throwing: error); return }
                if let s = item as? String { cont.resume(returning: s) }
                else if let data = item as? Data, let s = String(data: data, encoding: .utf8) {
                    cont.resume(returning: s)
                } else { cont.resume(throwing: ReaderError.extractionFailed("No text.")) }
            }
        }
    }

    // MARK: Handoff

    private func write(_ output: TextExtractor.Output, id: String) throws {
        guard let inbox = AppGroup.inboxURL else {
            throw ReaderError.extractionFailed("Shared container unavailable.")
        }
        let payload = InboxPayload(title: output.title, body: output.body, sourceKind: output.sourceKind)
        let data = try JSONEncoder().encode(payload)
        try data.write(to: inbox.appendingPathComponent("\(id).json"), options: .atomic)
    }

    private func openHostApp(documentID: String) {
        guard let url = AppGroup.openURL(documentID: documentID) else {
            return finish(error: ReaderError.extractionFailed("Couldn't open Outloud."))
        }
        // Extensions can't use UIApplication.shared; walk the responder chain.
        openURL(url)
        finish(error: nil)
    }

    @objc private func openURL(_ url: URL) {
        var responder: UIResponder? = self
        let selector = sel_registerName("openURL:")
        while let r = responder {
            if r.responds(to: selector), r !== self {
                _ = r.perform(selector, with: url)
                return
            }
            responder = r.next
        }
    }

    private func finish(error: Error?) {
        DispatchQueue.main.async {
            if let error {
                self.extensionContext?.cancelRequest(withError: error)
            } else {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }
}
