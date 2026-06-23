import Foundation
@preconcurrency import WebKit

/// Extracts the main article body from a web page using an offscreen WKWebView
/// with Mozilla **Readability.js** injected — strips nav/ads/boilerplate
/// (acceptance: a Safari article URL must read the article body only).
///
/// Runs on the main actor because WKWebView is main-thread-only. This is only
/// ever invoked from the host app (the extension hands off the URL and lets the
/// host do the fetch), keeping the extension's memory footprint tiny.
@MainActor
final class WebArticleExtractor: NSObject, WKNavigationDelegate {

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<TextExtractor.Output, Error>?
    private var sourceURL: URL?

    func extract(url: URL) async throws -> TextExtractor.Output {
        self.sourceURL = url
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let config = WKWebViewConfiguration()
            let webView = WKWebView(frame: .init(x: 0, y: 0, width: 1024, height: 1024),
                                    configuration: config)
            webView.navigationDelegate = self
            self.webView = webView
            webView.load(URLRequest(url: url))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Inject Readability, parse, return { title, textContent }.
        let js = Self.readabilityJS + "\n" + Self.runScript
        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self else { return }
            defer { self.teardown() }

            if let error {
                self.finish(.failure(ReaderError.extractionFailed(error.localizedDescription)))
                return
            }
            guard let dict = result as? [String: Any],
                  let text = dict["text"] as? String,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.finish(.failure(ReaderError.emptyDocument))
                return
            }
            let title = (dict["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? self.sourceURL?.host
                ?? "Article"
            let normalized = TextExtractor.normalize(text)
            self.finish(.success(.init(title: title, body: normalized, sourceKind: .web)))
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(ReaderError.extractionFailed(error.localizedDescription)))
        teardown()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(ReaderError.extractionFailed(error.localizedDescription)))
        teardown()
    }

    private func finish(_ result: Result<TextExtractor.Output, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }

    private func teardown() {
        webView?.navigationDelegate = nil
        webView = nil
    }

    // The Readability source is bundled as a resource and read once.
    private static let readabilityJS: String = {
        guard let url = Bundle.module.url(forResource: "Readability", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            // Should never happen in a correctly-built bundle.
            return ""
        }
        return source
    }()

    // Runs Readability against the live document and returns a JSON-able dict.
    private static let runScript = """
    (function () {
      try {
        var documentClone = document.cloneNode(true);
        var article = new Readability(documentClone).parse();
        if (!article) { return { title: document.title || "", text: "" }; }
        return { title: article.title || document.title || "", text: article.textContent || "" };
      } catch (e) {
        return { title: document.title || "", text: document.body ? document.body.innerText : "" };
      }
    })();
    """
}
