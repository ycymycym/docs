import Foundation

/// The static shelf of voices. The free tier exposes 3–4; the rest unlock with
/// the paid entitlement (brief §5). IDs match Kokoro's published voice
/// embedding names so `ModelManager` can resolve the embedding file for a voice.
///
/// This is the full English shelf Kokoro-82M ships. Non-English voices are
/// intentionally excluded in v1.
public enum VoiceCatalog {

    public static let all: [Voice] = [
        // ---- Free shelf (the hook: let them hear the good voice for free) ----
        Voice(id: "af_heart",  displayName: "Heart",  language: .americanEnglish, gender: .female, isFreeTier: true),
        Voice(id: "am_michael", displayName: "Michael", language: .americanEnglish, gender: .male,   isFreeTier: true),
        Voice(id: "bf_emma",   displayName: "Emma",   language: .britishEnglish,  gender: .female, isFreeTier: true),
        Voice(id: "bm_george", displayName: "George", language: .britishEnglish,  gender: .male,   isFreeTier: true),

        // ---- Paid shelf (packaging, not the value prop) ----
        Voice(id: "af_bella",   displayName: "Bella",   language: .americanEnglish, gender: .female, isFreeTier: false),
        Voice(id: "af_nicole",  displayName: "Nicole",  language: .americanEnglish, gender: .female, isFreeTier: false),
        Voice(id: "af_sarah",   displayName: "Sarah",   language: .americanEnglish, gender: .female, isFreeTier: false),
        Voice(id: "af_sky",     displayName: "Sky",     language: .americanEnglish, gender: .female, isFreeTier: false),
        Voice(id: "am_adam",    displayName: "Adam",    language: .americanEnglish, gender: .male,   isFreeTier: false),
        Voice(id: "am_echo",    displayName: "Echo",    language: .americanEnglish, gender: .male,   isFreeTier: false),
        Voice(id: "am_eric",    displayName: "Eric",    language: .americanEnglish, gender: .male,   isFreeTier: false),
        Voice(id: "am_liam",    displayName: "Liam",    language: .americanEnglish, gender: .male,   isFreeTier: false),
        Voice(id: "bf_alice",   displayName: "Alice",   language: .britishEnglish,  gender: .female, isFreeTier: false),
        Voice(id: "bf_lily",    displayName: "Lily",    language: .britishEnglish,  gender: .female, isFreeTier: false),
        Voice(id: "bm_daniel",  displayName: "Daniel",  language: .britishEnglish,  gender: .male,   isFreeTier: false),
        Voice(id: "bm_lewis",   displayName: "Lewis",   language: .britishEnglish,  gender: .male,   isFreeTier: false)
    ]

    public static let freeShelf = all.filter(\.isFreeTier)

    /// The default voice a brand-new user hears.
    public static let `default` = all.first(where: { $0.id == "af_heart" }) ?? all[0]

    public static func voice(id: String) -> Voice? {
        all.first(where: { $0.id == id })
    }

    /// The voices the user is allowed to pick right now, given entitlement.
    public static func available(unlocked: Bool) -> [Voice] {
        unlocked ? all : freeShelf
    }
}
