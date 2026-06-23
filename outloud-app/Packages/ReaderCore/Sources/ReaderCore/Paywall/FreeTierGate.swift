import Foundation

/// The free-tier length gate (brief §5). The hook is letting users *hear the
/// good voice for free*; the gate is **length, never voice quality**.
///
/// Cap: first **5 minutes of audio OR first 3000 characters**, whichever comes
/// first. When unlocked, the cap is removed entirely.
public struct FreeTierGate: Equatable, Sendable {
    public let maxCharacters: Int
    public let maxAudioDuration: TimeInterval

    public init(maxCharacters: Int = 3000, maxAudioDuration: TimeInterval = 300) {
        self.maxCharacters = maxCharacters
        self.maxAudioDuration = maxAudioDuration
    }

    public static let `default` = FreeTierGate()

    /// Should playback stop *before* speaking `sentence`?
    /// - Parameters:
    ///   - sentence: the next sentence about to be synthesized.
    ///   - accumulatedAudio: seconds of audio already synthesized this session.
    ///   - isUnlocked: paid entitlement present.
    public func limitReached(before sentence: Sentence,
                             accumulatedAudio: TimeInterval,
                             isUnlocked: Bool) -> Bool {
        if isUnlocked { return false }
        if sentence.characterOffset >= maxCharacters { return true }
        if accumulatedAudio >= maxAudioDuration { return true }
        return false
    }
}
