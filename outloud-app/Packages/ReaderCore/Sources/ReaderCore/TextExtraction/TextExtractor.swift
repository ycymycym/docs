import Foundation
import UniformTypeIdentifiers

/// The text-extraction entry point. Turns any supported input into a normalized
/// document body + a title. Used by BOTH the host app and the Share Extension
/// (extraction is cheap and memory-safe; only synthesis is forbidden in the
/// extension — brief §4).
public struct TextExtractor {

    public struct Output: Sendable {
        public let title: String
        public let body: String
        public let sourceKind: ReaderDocument.SourceKind
    }

    public init() {}

    /// Dispatches on the input type. Order mirrors build order §5: PDF (+OCR
    /// fallback), web URL (Readability), plain text.
    public func extract(from input: ExtractionInput) async throws -> Output {
        switch input {
        case .pdf(let url):
            return try await PDFTextExtractor().extract(url: url)
        case .webURL(let url):
            return try await WebArticleExtractor().extract(url: url)
        case .plainText(let text, let title):
            return try PlainTextExtractor().extract(text: text, title: title)
        }
    }

    /// Normalizes raw extracted text: collapse runaway whitespace, repair common
    /// PDF artifacts (hyphenated line breaks, stray form-feeds) so the TTS doesn't
    /// read garbage. Kept deliberately conservative.
    static func normalize(_ raw: String) -> String {
        var text = raw.replacingOccurrences(of: "\u{0C}", with: "\n") // form feed
        // De-hyphenate words split across line breaks: "exam-\nple" → "example".
        text = text.replacingOccurrences(
            of: "(\\w)-\\n(\\w)", with: "$1$2", options: .regularExpression)
        // Single newlines inside a paragraph → spaces; keep blank-line breaks.
        text = text.replacingOccurrences(
            of: "([^\\n])\\n([^\\n])", with: "$1 $2", options: .regularExpression)
        // Collapse 3+ blank lines and runs of spaces.
        text = text.replacingOccurrences(
            of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(
            of: "[ \\t]{2,}", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// The inputs the pipeline accepts, matching the Share Extension's declared
/// types: public.pdf, public.url, public.plain-text / public.text.
public enum ExtractionInput: Sendable {
    case pdf(URL)
    case webURL(URL)
    case plainText(String, title: String)
}
