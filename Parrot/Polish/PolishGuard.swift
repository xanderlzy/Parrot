import Foundation

/// Pure helpers that keep the on-device model honest: split long dictation into
/// model-sized pieces, and reject output that isn't a cleanup of the input.
enum PolishGuard {
    static func chunks(_ text: String, maxWords: Int = 250) -> [String] {
        var chunks: [String] = []
        var current: [String] = []
        func flush() {
            if !current.isEmpty { chunks.append(current.joined(separator: " ")); current = [] }
        }
        for sentence in sentences(text) {
            let words = sentence.split(whereSeparator: \.isWhitespace).map(String.init)
            if words.count > maxWords {
                flush()
                for start in stride(from: 0, to: words.count, by: maxWords) {
                    chunks.append(words[start..<min(start + maxWords, words.count)].joined(separator: " "))
                }
                continue
            }
            if current.count + words.count > maxWords { flush() }
            current.append(contentsOf: words)
        }
        flush()
        return chunks
    }

    /// Sentences ending in . ! or ? (punctuation kept); a trailing fragment counts as a sentence.
    private static func sentences(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        let chars = Array(text)
        for (i, ch) in chars.enumerated() {
            current.append(ch)
            let next = i + 1 < chars.count ? chars[i + 1] : " "
            if ".!?".contains(ch), next.isWhitespace {
                result.append(current); current = ""
            }
        }
        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(current) }
        return result
    }

    static func accept(raw: String, polished: String) -> Bool {
        let trimmed = polished.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.count <= Int(Double(raw.count) * 1.3) + 20
    }
}
