import Foundation

private enum StableIdentifier {
    static func isValid(_ value: String) -> Bool {
        guard let first = value.first,
              first.isASCIILowercaseLetter || first.isASCIIDigit else {
            return false
        }

        var previousWasHyphen = false
        for character in value {
            if character == "-" {
                if previousWasHyphen { return false }
                previousWasHyphen = true
            } else if character.isASCIILowercaseLetter || character.isASCIIDigit {
                previousWasHyphen = false
            } else {
                return false
            }
        }
        return !previousWasHyphen
    }
}

private extension Character {
    var isASCIILowercaseLetter: Bool {
        unicodeScalars.count == 1 && unicodeScalars.first.map { (97...122).contains($0.value) } == true
    }

    var isASCIIDigit: Bool {
        unicodeScalars.count == 1 && unicodeScalars.first.map { (48...57).contains($0.value) } == true
    }
}

public struct CourseID: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init?(rawValue: String) {
        guard StableIdentifier.isValid(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "CourseID must be a stable lowercase identifier."
            )
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }
}

public struct EntryID: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init?(rawValue: String) {
        guard StableIdentifier.isValid(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "EntryID must be a stable lowercase identifier."
            )
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }
}

public struct CourseCollectionID: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init?(rawValue: String) {
        guard StableIdentifier.isValid(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "CourseCollectionID must be a stable lowercase identifier."
            )
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }
}
