import Foundation

/// A selectable voice. Kokoro voices are embedding tensors ("style vectors")
/// shipped *alongside* the model — KokoroSwift's README is explicit that
/// "voice styles are moved out of the library to the integrating application",
/// so the app owns loading them.
///
/// IMPORTANT positioning note (brief §1): voices are NOT the moat. This type
/// exists for paywall *packaging* (free shelf vs. full shelf), not because
/// voices are the value prop. Don't build UI that worships voices.
public struct Voice: Identifiable, Equatable, Sendable, Codable {
    public let id: String          // e.g. "af_heart" — matches the embedding file name
    public let displayName: String // e.g. "Heart"
    public let language: VoiceLanguage
    public let gender: Gender
    /// Whether this voice is available on the free shelf. Paid unlocks all.
    public let isFreeTier: Bool

    public enum Gender: String, Codable, Sendable { case female, male, neutral }

    public init(id: String, displayName: String, language: VoiceLanguage,
                gender: Gender, isFreeTier: Bool) {
        self.id = id
        self.displayName = displayName
        self.language = language
        self.gender = gender
        self.isFreeTier = isFreeTier
    }
}

/// The accents Kokoro ships for English. We only expose English in v1 (the
/// product reads English; v1.1 translates *into* English first).
public enum VoiceLanguage: String, Codable, Sendable, CaseIterable {
    case americanEnglish = "en-US"
    case britishEnglish = "en-GB"

    public var displayName: String {
        switch self {
        case .americanEnglish: return "American"
        case .britishEnglish: return "British"
        }
    }
}
