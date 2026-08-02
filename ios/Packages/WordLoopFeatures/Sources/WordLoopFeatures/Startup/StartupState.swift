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
            return copy.start
        case .preparing, .restoring:
            return copy.preparing
        case .syncing:
            return copy.syncing
        case .ready:
            return copy.ready
        case .error:
            return copy.retry
        }
    }

    public var helperText: String? {
        let copy = StartupCopy.current
        switch self {
        case .idle:
            return nil
        case .preparing, .restoring:
            return copy.restoring
        case .syncing:
            return copy.syncingProgress
        case .ready:
            return nil
        case .error:
            return copy.offline
        }
    }

    public var isBusy: Bool {
        self == .preparing || self == .restoring || self == .syncing
    }
}
