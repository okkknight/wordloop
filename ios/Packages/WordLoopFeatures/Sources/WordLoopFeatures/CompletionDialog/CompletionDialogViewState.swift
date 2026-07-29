public struct CompletionDialogViewState: Equatable, Sendable {
    public static let fixtureCourseID = "modern-family-s01e01"
    public static let fixedErrorMessage = "暂时无法重置进度，请稍后重试。"

    public var kind: CompletionDialogKind
    public var courseID: String
    public var errorMessage: String? {
        didSet { errorMessage = Self.sanitizedError(errorMessage) }
    }
    public var isPresented: Bool

    public init(
        kind: CompletionDialogKind = .restartCompletedCourse,
        courseID: String = CompletionDialogViewState.fixtureCourseID,
        errorMessage: String? = nil,
        isPresented: Bool = false
    ) {
        self.kind = kind
        self.courseID = courseID
        self.errorMessage = Self.sanitizedError(errorMessage)
        self.isPresented = isPresented
    }

    public static func fixture(arguments: [String]) -> CompletionDialogViewState {
        guard let rawKind = value(after: "-wordloop-completion-dialog", in: arguments)?.lowercased(),
              let kind = fixtureKind(rawKind) else {
            return .init()
        }

        return .init(
            kind: kind,
            courseID: fixtureCourseID,
            errorMessage: arguments.contains("-wordloop-completion-error") ? fixedErrorMessage : nil,
            isPresented: true
        )
    }

    private static func fixtureKind(_ rawValue: String) -> CompletionDialogKind? {
        switch rawValue {
        case "restart": .restartCompletedCourse
        case "complete": .courseCompleted
        default: nil
        }
    }

    private static func value(after key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func sanitizedError(_ error: String?) -> String? {
        error == fixedErrorMessage ? fixedErrorMessage : nil
    }
}
