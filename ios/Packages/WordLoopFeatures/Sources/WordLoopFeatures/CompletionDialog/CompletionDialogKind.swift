public enum CompletionDialogKind: String, CaseIterable, Equatable, Sendable {
    case restartCompletedCourse
    case courseCompleted

    public var kicker: String { CompletionDialogCopy.current.kicker }

    public var title: String {
        let copy = CompletionDialogCopy.current
        switch self {
        case .restartCompletedCourse: return copy.restartTitle
        case .courseCompleted: return copy.completedTitle
        }
    }

    public var message: String {
        let copy = CompletionDialogCopy.current
        switch self {
        case .restartCompletedCourse: return copy.restartMessage
        case .courseCompleted: return copy.completedMessage
        }
    }

    public var cancelTitle: String {
        let copy = CompletionDialogCopy.current
        switch self {
        case .restartCompletedCourse: return copy.cancel
        case .courseCompleted: return copy.chooseCourse
        }
    }

    public var confirmTitle: String {
        let copy = CompletionDialogCopy.current
        switch self {
        case .restartCompletedCourse: return copy.restart
        case .courseCompleted: return copy.practiceAgain
        }
    }

    public var accessibilityLabel: String {
        "\(kicker)，\(title)，\(message)"
    }
}
