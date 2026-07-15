import Foundation

public struct StudyHighlightRange: Equatable, Hashable, Sendable {
    public let lowerBound: Int
    public let upperBound: Int

    public init(_ lowerBound: Int, _ upperBound: Int) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }
}

public struct StudyShellTextSegment: Equatable, Sendable {
    public let text: String
    public let isHighlighted: Bool

    public init(text: String, isHighlighted: Bool) {
        self.text = text
        self.isHighlighted = isHighlighted
    }
}

public struct StudyShellItem: Identifiable, Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case sentence
        case word
    }

    public let id: String
    public let kind: Kind
    public let english: String
    public let phonetic: String?
    public let translation: String
    public let highlightRanges: [StudyHighlightRange]

    public init(
        id: String,
        kind: Kind,
        english: String,
        phonetic: String? = nil,
        translation: String,
        highlightRanges: [StudyHighlightRange] = []
    ) {
        self.id = id
        self.kind = kind
        self.english = english
        self.phonetic = phonetic
        self.translation = translation
        self.highlightRanges = highlightRanges
    }

    /// Resolves character offsets only when the complete range set is valid.
    /// Invalid, empty, unsorted, or overlapping inputs deliberately produce no
    /// highlight instead of partially styling the learning text.
    public func resolvedHighlightRanges() -> [Range<String.Index>] {
        let characterCount = english.count
        var previousUpperBound = 0
        var resolved: [Range<String.Index>] = []

        for range in highlightRanges {
            guard range.lowerBound >= previousUpperBound,
                  range.lowerBound >= 0,
                  range.upperBound > range.lowerBound,
                  range.upperBound <= characterCount else {
                return []
            }

            let lower = english.index(english.startIndex, offsetBy: range.lowerBound)
            let upper = english.index(english.startIndex, offsetBy: range.upperBound)
            resolved.append(lower..<upper)
            previousUpperBound = range.upperBound
        }
        return resolved
    }

    public func textSegments() -> [StudyShellTextSegment] {
        let ranges = resolvedHighlightRanges()
        guard !ranges.isEmpty else {
            return [StudyShellTextSegment(text: english, isHighlighted: false)]
        }

        var result: [StudyShellTextSegment] = []
        var cursor = english.startIndex
        for range in ranges {
            if cursor < range.lowerBound {
                result.append(.init(text: String(english[cursor..<range.lowerBound]), isHighlighted: false))
            }
            result.append(.init(text: String(english[range]), isHighlighted: true))
            cursor = range.upperBound
        }
        if cursor < english.endIndex {
            result.append(.init(text: String(english[cursor...]), isHighlighted: false))
        }
        return result
    }

    /// Finds every non-overlapping, exact occurrence using Character offsets.
    /// This preserves repeated words and punctuation without global replace.
    public static func highlightRanges(matching token: String, in text: String) -> [StudyHighlightRange] {
        guard !token.isEmpty else { return [] }
        var result: [StudyHighlightRange] = []
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let match = text.range(of: token, range: searchStart..<text.endIndex) {
            result.append(.init(
                text.distance(from: text.startIndex, to: match.lowerBound),
                text.distance(from: text.startIndex, to: match.upperBound)
            ))
            searchStart = match.upperBound
        }
        return result
    }
}
