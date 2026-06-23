import Foundation

/// Trivial extractor for pasted text and public.plain-text / public.text shares.
struct PlainTextExtractor {
    func extract(text: String, title: String?) throws -> TextExtractor.Output {
        let normalized = TextExtractor.normalize(text)
        guard !normalized.isEmpty else { throw ReaderError.emptyDocument }
        let resolvedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = (resolvedTitle?.isEmpty == false ? resolvedTitle! : Self.derivedTitle(from: normalized))
        return .init(title: finalTitle, body: normalized, sourceKind: .plainText)
    }

    /// First few words make a serviceable title for pasted text.
    private static func derivedTitle(from text: String) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace }).prefix(6)
        let joined = words.joined(separator: " ")
        return joined.isEmpty ? "Pasted text" : joined + (text.count > joined.count ? "…" : "")
    }
}
