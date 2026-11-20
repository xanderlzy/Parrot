import Testing
@testable import Parrot

struct PolishGuardTests {
    private func normalized(_ s: String) -> String {
        s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private var sixHundredWords: String {
        (0..<30).map { i in
            (0..<19).map { "word\(i)x\($0)" }.joined(separator: " ") + " end."
        }.joined(separator: " ")
    }

    @Test func chunksSplitAtSentenceBoundaries() {
        let chunks = PolishGuard.chunks(sixHundredWords, maxWords: 250)
        #expect(chunks.count >= 3)
        for c in chunks {
            #expect(c.split(whereSeparator: \.isWhitespace).count <= 250)
            #expect(c.hasSuffix("."))
        }
    }

    @Test func longInputIsChunkedAndFullyPreserved() {
        let chunks = PolishGuard.chunks(sixHundredWords, maxWords: 250)
        #expect(normalized(chunks.joined(separator: " ")) == normalized(sixHundredWords))
    }

    @Test func runOnSentenceSplitsAtWords() {
        let text = (0..<600).map { "w\($0)" }.joined(separator: " ")
        let chunks = PolishGuard.chunks(text, maxWords: 250)
        #expect(chunks.map { $0.split(separator: " ").count } == [250, 250, 100])
        #expect(normalized(chunks.joined(separator: " ")) == text)
    }

    @Test func shortTextIsOneChunk() {
        #expect(PolishGuard.chunks("Hello there.") == ["Hello there."])
    }

    @Test func acceptRejectsEmptyAndRunaway() {
        #expect(!PolishGuard.accept(raw: "hi there", polished: "   "))
        #expect(!PolishGuard.accept(raw: "what's the weather tomorrow",
                                    polished: String(repeating: "It will be sunny. ", count: 12)))
        #expect(PolishGuard.accept(raw: "um so I think we should uh meet", polished: "I think we should meet."))
    }
}
