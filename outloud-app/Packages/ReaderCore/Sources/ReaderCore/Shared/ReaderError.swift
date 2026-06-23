import Foundation

/// User-surfaceable errors. Anything thrown deep in the pipeline is mapped to
/// one of these so the UI always has a clean message + recovery hint.
public enum ReaderError: LocalizedError, Equatable {
    case emptyDocument
    case unsupportedType(String)
    case extractionFailed(String)
    case modelDownloadFailed(String)
    case modelMissing
    case synthesisFailed(String)
    case audioSessionFailed(String)
    case purchaseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyDocument:
            return "We couldn't find any readable text in this document."
        case .unsupportedType(let t):
            return "That file type isn't supported yet (\(t))."
        case .extractionFailed(let why):
            return "Couldn't read the document. \(why)"
        case .modelDownloadFailed(let why):
            return "The voice model couldn't be downloaded. \(why)"
        case .modelMissing:
            return "The voice model isn't installed yet."
        case .synthesisFailed(let why):
            return "Something went wrong while generating audio. \(why)"
        case .audioSessionFailed(let why):
            return "Audio couldn't start. \(why)"
        case .purchaseFailed(let why):
            return "The purchase couldn't be completed. \(why)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .emptyDocument:
            return "Try a different file, or paste the text directly."
        case .modelDownloadFailed, .modelMissing:
            return "Check your connection and tap Retry. The model only downloads once."
        default:
            return nil
        }
    }
}
