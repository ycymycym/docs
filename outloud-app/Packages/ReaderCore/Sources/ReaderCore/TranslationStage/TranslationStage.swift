import Foundation

/// The v1.1 seam (brief §7).
///
/// In v1 this is a **passthrough**: text in == text out. It sits between
/// TextExtraction and Chunking so that in v1.1 we can drop in an
/// implementation that detects the source language and, when it isn't English,
/// runs Apple's on-device Translation framework (iOS 18) before chunking —
/// turning "Kokoro can't read other languages well" into a non-issue because
/// the output is always English.
///
/// Keeping this as a protocol now means v1.1 is a one-line swap in the
/// pipeline assembly, with zero churn in Chunking/Playback.
public protocol TranslationStage: Sendable {
    /// Transform a fully-extracted document body before chunking.
    /// - Parameter progress: 0...1, for a future "Translating…" UI. Passthrough
    ///   reports 1.0 immediately.
    func process(_ text: String, progress: @Sendable (Double) -> Void) async throws -> TranslationResult
}

/// Result carries the (possibly translated) text plus metadata the UI may want
/// to show later ("Translated from Spanish"). In v1 it always reports English
/// and `didTranslate == false`.
public struct TranslationResult: Sendable, Equatable {
    public let text: String
    public let detectedSourceLanguage: String?   // BCP-47, nil if unknown
    public let didTranslate: Bool

    public init(text: String, detectedSourceLanguage: String?, didTranslate: Bool) {
        self.text = text
        self.detectedSourceLanguage = detectedSourceLanguage
        self.didTranslate = didTranslate
    }
}

/// v1 implementation. Does nothing but forward the text.
public struct PassthroughTranslationStage: TranslationStage {
    public init() {}

    public func process(
        _ text: String,
        progress: @Sendable (Double) -> Void
    ) async throws -> TranslationResult {
        progress(1.0)
        return TranslationResult(
            text: text,
            detectedSourceLanguage: nil,
            didTranslate: false
        )
    }
}
