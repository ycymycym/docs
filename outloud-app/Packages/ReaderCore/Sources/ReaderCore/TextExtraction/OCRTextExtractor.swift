import Foundation
import Vision
import PDFKit
import CoreGraphics

/// Vision OCR fallback for scanned/image PDFs. Rasterizes each page and runs
/// `VNRecognizeTextRequest` with `.accurate`. Pages are processed one at a time
/// to keep memory bounded (this can run during share-extension extraction too,
/// where the budget is tight).
struct OCRTextExtractor {

    func recognizeText(in document: PDFDocument) async throws -> String {
        var pages: [String] = []
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let image = rasterize(page: page)
            if let cg = image {
                let text = try await recognize(cgImage: cg)
                pages.append(text)
            }
        }
        let joined = pages.joined(separator: "\n\n")
        guard !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReaderError.extractionFailed("No readable text was found, even with OCR.")
        }
        return joined
    }

    private func rasterize(page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        // 2x scale keeps small body text legible without exploding memory.
        let scale: CGFloat = 2.0
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }

    private func recognize(cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: ReaderError.extractionFailed(error.localizedDescription))
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "en-GB"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do { try handler.perform([request]) }
            catch { continuation.resume(throwing: ReaderError.extractionFailed(error.localizedDescription)) }
        }
    }
}
