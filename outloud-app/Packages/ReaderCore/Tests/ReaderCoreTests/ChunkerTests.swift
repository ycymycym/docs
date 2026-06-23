import XCTest
@testable import ReaderCore

final class ChunkerTests: XCTestCase {

    func testSentenceSegmentation() {
        let text = "Hello there. This is a test! Is it working? Yes."
        let s = Chunker().sentences(in: text)
        XCTAssertEqual(s.count, 4)
        XCTAssertEqual(s[0].text, "Hello there.")
        XCTAssertEqual(s[0].id, 0)
        XCTAssertEqual(s[3].text, "Yes.")
    }

    func testCharacterOffsetsAreMonotonic() {
        let text = "One. Two. Three."
        let s = Chunker().sentences(in: text)
        XCTAssertEqual(s.map(\.characterOffset), s.map(\.characterOffset).sorted())
        XCTAssertEqual(s.first?.characterOffset, 0)
    }

    func testChunksRespectSentenceCountCap() {
        let sentences = (0..<20).map {
            Sentence(id: $0, text: "Short one.", characterOffset: $0 * 10)
        }
        let chunks = Chunker(config: .init(maxTokensPerChunk: 10_000, maxSentencesPerChunk: 6))
            .chunks(from: sentences)
        XCTAssertTrue(chunks.allSatisfy { $0.sentences.count <= 6 })
        // No sentence is dropped.
        XCTAssertEqual(chunks.flatMap(\.sentences).count, 20)
    }

    func testLongSentenceBecomesItsOwnChunk() {
        let long = String(repeating: "word ", count: 500) + "."
        let sentences = [Sentence(id: 0, text: long, characterOffset: 0)]
        let chunks = Chunker().chunks(from: sentences)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].sentences.count, 1)
    }

    func testEmptyInputProducesNoChunks() {
        XCTAssertTrue(Chunker().chunk("   \n  ").isEmpty)
    }
}
