import Foundation

public struct RepeatScoreResult: Equatable, Sendable {
    public let passed: Bool
    public let score: Int
    public let matched: String

    public init(passed: Bool, score: Int, matched: String) {
        self.passed = passed
        self.score = score
        self.matched = matched
    }
}

public enum RepeatScorer {
    public static let passScore = 20
    public static let minimumSentenceWordCoverage = 0.6

    public static func score(target: String, transcript: String, sentence: Bool) -> RepeatScoreResult {
        let normalizedTarget = normalizeSpeech(target)
        let candidates = speechCandidates(transcript)
        var matched = ""
        var bestSimilarity = 0.0
        for candidate in candidates {
            let distance = levenshtein(normalizedTarget, candidate)
            let denominator = max(normalizedTarget.count, candidate.count, 1)
            let similarity = max(0, 1 - Double(distance) / Double(denominator))
            if similarity > bestSimilarity {
                bestSimilarity = similarity
                matched = candidate
            }
        }
        let exact = candidates.contains(normalizedTarget)
        let rawScore = exact ? 100 : Int((bestSimilarity * 100).rounded(.toNearestOrAwayFromZero))
        let lexicalPass = exact || rawScore >= passScore
        let coveragePass = !sentence || sentenceWordCoverage(target: target, transcript: transcript) >= minimumSentenceWordCoverage
        return RepeatScoreResult(
            passed: lexicalPass && coveragePass,
            score: matched.isEmpty ? 0 : rawScore,
            matched: matched
        )
    }

    public static func normalizeSpeech(_ value: String) -> String {
        value.lowercased().unicodeScalars.reduce(into: "") { result, scalar in
            if scalar.value >= 97, scalar.value <= 122 { result.unicodeScalars.append(scalar) }
        }
    }

    public static func speechCandidates(_ transcript: String) -> [String] {
        let pattern = #"[\[(](?:background noise|noise|music|laughter|silence|inaudible)[\])]"#
        let range = NSRange(transcript.startIndex..., in: transcript)
        let cleaned = (try? NSRegularExpression(pattern: pattern, options: .caseInsensitive))?
            .stringByReplacingMatches(in: transcript, range: range, withTemplate: " ") ?? transcript
        let words = cleaned.split(whereSeparator: \Character.isWhitespace).map { normalizeSpeech(String($0)) }.filter { !$0.isEmpty }
        var values: [String] = []
        var seen: Set<String> = []
        func append(_ value: String) {
            if seen.insert(value).inserted { values.append(value) }
        }
        words.forEach(append)
        for start in words.indices {
            var combined = words[start]
            let upperBound = min(words.count, start + 12)
            if start + 1 < upperBound {
                for end in (start + 1)..<upperBound {
                    combined += words[end]
                    append(combined)
                }
            }
        }
        return values
    }

    public static func sentenceWordCoverage(target: String, transcript: String) -> Double {
        let targetWords = target.split(whereSeparator: \Character.isWhitespace).map { normalizeCoverageWord(String($0)) }.filter { !$0.isEmpty }
        let spokenWords = Set(transcript.split(whereSeparator: \Character.isWhitespace).map { normalizeCoverageWord(String($0)) }.filter { !$0.isEmpty })
        guard !targetWords.isEmpty else { return 0 }
        return Double(targetWords.filter(spokenWords.contains).count) / Double(targetWords.count)
    }

    public static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs), b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for (row, left) in a.enumerated() {
            var current = [row + 1] + Array(repeating: 0, count: b.count)
            for (column, right) in b.enumerated() {
                current[column + 1] = min(
                    previous[column + 1] + 1,
                    current[column] + 1,
                    previous[column] + (left == right ? 0 : 1)
                )
            }
            previous = current
        }
        return previous[b.count]
    }

    private static func normalizeCoverageWord(_ value: String) -> String {
        let lowered = value.lowercased().replacingOccurrences(of: "’", with: "'")
        let scalars = Array(lowered.unicodeScalars)
        let allowed: (UnicodeScalar) -> Bool = { ($0.value >= 97 && $0.value <= 122) || $0 == "'" }
        guard let first = scalars.firstIndex(where: allowed), let last = scalars.lastIndex(where: allowed) else { return "" }
        let word = String(String.UnicodeScalarView(scalars[first...last]))
        if word == "'em" || word == "em" { return "them" }
        if let apostrophe = word.firstIndex(of: "'"), apostrophe != word.startIndex {
            let suffix = String(word[word.index(after: apostrophe)...])
            if ["d", "ll", "re", "ve", "m", "s"].contains(suffix) {
                let stem = String(word[..<apostrophe])
                if stem.allSatisfy({ $0 >= "a" && $0 <= "z" }) { return stem }
            }
        }
        return normalizeSpeech(word)
    }
}
