import XCTest
@testable import ReaderCore

final class FreeTierGateTests: XCTestCase {

    private func sentence(offset: Int) -> Sentence {
        Sentence(id: 0, text: "x", characterOffset: offset)
    }

    func testUnlockedNeverHitsLimit() {
        let gate = FreeTierGate.default
        XCTAssertFalse(gate.limitReached(before: sentence(offset: 999_999),
                                         accumulatedAudio: 99_999,
                                         isUnlocked: true))
    }

    func testCharacterCapTrips() {
        let gate = FreeTierGate(maxCharacters: 3000, maxAudioDuration: 300)
        XCTAssertFalse(gate.limitReached(before: sentence(offset: 2999),
                                         accumulatedAudio: 0, isUnlocked: false))
        XCTAssertTrue(gate.limitReached(before: sentence(offset: 3000),
                                        accumulatedAudio: 0, isUnlocked: false))
    }

    func testAudioDurationCapTrips() {
        let gate = FreeTierGate(maxCharacters: 10_000, maxAudioDuration: 300)
        XCTAssertFalse(gate.limitReached(before: sentence(offset: 0),
                                         accumulatedAudio: 299, isUnlocked: false))
        XCTAssertTrue(gate.limitReached(before: sentence(offset: 0),
                                        accumulatedAudio: 300, isUnlocked: false))
    }

    func testWhicheverComesFirst() {
        // Character cap reached well before the time cap.
        let gate = FreeTierGate(maxCharacters: 100, maxAudioDuration: 300)
        XCTAssertTrue(gate.limitReached(before: sentence(offset: 150),
                                        accumulatedAudio: 5, isUnlocked: false))
    }
}
