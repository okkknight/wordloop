public enum CompletionDialogKind: String, CaseIterable, Equatable, Sendable {
    case restartCompletedCourse
    case courseCompleted

    public var kicker: String { CompletionDialogCopy.current.kicker }

    public var title: String {
        let copy = CompletionDialogCopy.current
        switch self {
        case .restartCompletedCourse: copy.restartTitle
        case .courseCompleted: copy.completedTitle
        }
    }

    public var message: String {
        let copy = CompletionDialogCopy.current
        switch self {
        case .restartCompletedCourse: copy.restartMessage
        case .courseCompleted: copy.completedMessage
        }
    }

    public var cancelTitle: String {
        let copy = CompletionDialogCopy.current
        switch self {
        case .restartCompletedCourse: copy.cancel
        case .courseCompleted: copy.chooseCourse
        }
    }

    public var confirmTitle: String {
        let copy = CompletionDialogCopy.current
        switch self {
        case .restartCompletedCourse: copy.restart
        case .courseCompleted: copy.practiceAgain
        }
    }

    public var accessibilityLabel: String {
        "\(kicker)，\(title)，\(message)"
    }
}
