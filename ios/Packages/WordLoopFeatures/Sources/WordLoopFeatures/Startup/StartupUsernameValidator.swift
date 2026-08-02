import Foundation

public enum StartupUsernameValidationResult: Equatable, Sendable {
    case valid(StartupSubmission)
    case invalid(message: String)
}

public enum StartupUsernameValidator {
    public static let maximumLength = 32
    public static var invalidUsernameMessage: String { StartupUsernameCopy.current.invalid }

    public static func constrainedInput(_ input: String) -> String {
        String(input.prefix(maximumLength))
    }

    public static func validate(_ input: String) -> StartupUsernameValidationResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .valid(.anonymous)
        }

        let isASCIIEnglishLetters = trimmed.utf8.allSatisfy { byte in
            (65...90).contains(byte) || (97...122).contains(byte)
        }

        guard isASCIIEnglishLetters else {
            return .invalid(message: invalidUsernameMessage)
        }

        return .valid(.named(trimmed.lowercased()))
    }
}
