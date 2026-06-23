import Foundation
import PDFKit

/// Extracts text from a PDF via PDFKit, falling back to Vision OCR when the PDF
/// is scanned/image-only (brief §3 + acceptance: a scanned PDF must be read).
struct PDFTextExtractor {

    func extract(url: URL) async throws -> TextExtractor.Output {
        // Security-scoped access for files shared from Files/other apps.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url) else {
            throw ReaderError.extractionFailed("The PDF couldn't be opened.")
        }

        let title = Self.title(for: document, fallback: url.deletingPathExtension().lastPathComponent)

        // 1) Fast path: embedded text layer.
        let embedded = embeddedText(from: document)

        // 2) Decide if it's effectively textless (scanned). Heuristic: very few
        //    characters relative to page count → OCR fallback.
        let pageCount = max(1, document.pageCount)
        let charsPerPage = Double(embedded.count) / Double(pageCount)
        let body: String
        if charsPerPage < 30 {
            Log.extraction.info("PDF looks scanned (\(Int(charsPerPage)) chars/page) → OCR fallback")
            body = try await OCRTextExtractor().recognizeText(in: document)
        } else {
            body = embedded
        }

        let normalized = TextExtractor.normalize(body)
        guard !normalized.isEmpty else { throw ReaderError.emptyDocument }
        return .init(title: title, body: normalized, sourceKind: .pdf)
    }

    private func embeddedText(from document: PDFDocument) -> String {
        var parts: [String] = []
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let s = page.string {
                parts.append(s)
            }
        }
        return parts.joined(separator: "\n\n")
    }

    private static func title(for document: PDFDocument, fallback: String) -> String {
        if let t = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String,
           !t.trimmingCharacters(in: .whitespaces).isEmpty {
            return t
        }
        return fallback
    }
}
