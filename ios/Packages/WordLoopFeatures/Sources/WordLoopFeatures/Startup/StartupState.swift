public enum StartupState: String, CaseIterable, Equatable, Sendable {
    case idle
    case preparing
    case restoring
    case syncing
    case ready
    case error

    public var buttonTitle: String {
        let copy = StartupCopy.current
        switch self {
        case .idle:
            copy.start
        case .preparing, .restoring:
            copy.preparing
        case .syncing:
            copy.syncing
        case .ready:
            copy.ready
        case .error:
            copy.retry
        }
    }

    public var helperText: String? {
        let copy = StartupCopy.current
        switch self {
        case .idle:
            nil
        case .preparing, .restoring:
            copy.restoring
        case .syncing:
            copy.syncingProgress
        case .ready:
            nil
        case .error:
            copy.offline
        }
    }

    public var isBusy: Bool {
        self == .preparing || self == .restoring || self == .syncing
    }
}
