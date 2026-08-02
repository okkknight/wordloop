import Foundation

public struct ProgressDrawerEntry: Identifiable, Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case sentence
        case word
    }

    public let id: String
    public let kind: Kind
    public let primaryText: String
    public let secondaryText: String
    public var studyCount: Int {
        didSet { studyCount = Self.clamp(studyCount) }
    }

    public init(
        id: String,
        kind: Kind,
        primaryText: String,
        secondaryText: String,
        studyCount: Int
    ) {
        self.id = id
        self.kind = kind
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.studyCount = Self.clamp(studyCount)
    }

    public var countLabel: String { "\(studyCount) / 3" }
    public var isMastered: Bool { studyCount == 3 }

    public var accessibilityLabel: String {
        let copy = ProgressDrawerEntryCopy.current
        let mastered = isMastered ? ", \(copy.mastered)" : ""
        return "\(primaryText), \(secondaryText), \(copy.studied) \(studyCount) \(copy.total) 3\(mastered)"
    }

    public func matches(_ normalizedQuery: String) -> Bool {
        primaryText.lowercased().contains(normalizedQuery)
            || secondaryText.lowercased().contains(normalizedQuery)
    }

    private static func clamp(_ count: Int) -> Int {
        min(max(count, 0), 3)
    }
}
