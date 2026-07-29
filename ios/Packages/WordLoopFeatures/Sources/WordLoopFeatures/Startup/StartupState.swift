public enum StartupState: String, CaseIterable, Equatable, Sendable {
    case idle
    case preparing
    case restoring
    case syncing
    case ready
    case error

    public var buttonTitle: String {
        switch self {
        case .idle:
            "START"
        case .preparing, .restoring:
            "PREPARING…"
        case .syncing:
            "SYNCING…"
        case .ready:
            "READY"
        case .error:
            "RETRY"
        }
    }

    public var helperText: String? {
        switch self {
        case .idle:
            nil
        case .preparing, .restoring:
            "正在恢复上次课程"
        case .syncing:
            "正在同步学习进度"
        case .ready:
            nil
        case .error:
            "无法同步，仍可使用本地课程"
        }
    }

    public var isBusy: Bool {
        self == .preparing || self == .restoring || self == .syncing
    }
}
