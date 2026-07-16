public enum CompletionDialogKind: String, CaseIterable, Equatable, Sendable {
    case restartCompletedCourse
    case courseCompleted

    public var kicker: String { "COURSE COMPLETE" }

    public var title: String {
        switch self {
        case .restartCompletedCourse: "这门课程已经完成"
        case .courseCompleted: "这门课程学完了"
        }
    }

    public var message: String {
        switch self {
        case .restartCompletedCourse: "要重新开始练习吗？现有练习进度将被清零。"
        case .courseCompleted: "太棒了。你可以从头再练一遍，或者挑选下一门课程继续学习。"
        }
    }

    public var cancelTitle: String {
        switch self {
        case .restartCompletedCourse: "取消"
        case .courseCompleted: "选择课程"
        }
    }

    public var confirmTitle: String {
        switch self {
        case .restartCompletedCourse: "重新开始"
        case .courseCompleted: "再练一次"
        }
    }

    public var accessibilityLabel: String {
        "\(kicker)，\(title)，\(message)"
    }
}
