public enum StartupState: String, CaseIterable, Equatable, Sendable {
    case idle
    case preparing
    case syncing

    public var buttonTitle: String {
        switch self {
        case .idle:
            "START"
        case .preparing:
            "PREPARING…"
        case .syncing:
            "SYNCING…"
        }
    }

    public var helperText: String? {
        switch self {
        case .idle:
            nil
        case .preparing:
            "正在恢复上次课程"
        case .syncing:
            "正在同步学习进度"
        }
    }

    public var isBusy: Bool {
        self != .idle
    }
}
