import Foundation

public enum WordLoopHapticEvent: Equatable, Sendable {
    case selection
    case impact
    case success
    case failure
}

public protocol WordLoopHaptics: Sendable {
    func perform(_ event: WordLoopHapticEvent)
}

public struct NoOpWordLoopHaptics: WordLoopHaptics {
    public init() {}
    public func perform(_ event: WordLoopHapticEvent) {}
}

public final class RecordingWordLoopHaptics: WordLoopHaptics, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [WordLoopHapticEvent] = []

    public init() {}

    public var events: [WordLoopHapticEvent] {
        lock.withLock { storage }
    }

    public func perform(_ event: WordLoopHapticEvent) {
        lock.withLock { storage.append(event) }
    }
}

#if os(iOS)
import UIKit

public final class UIKitWordLoopHaptics: WordLoopHaptics, @unchecked Sendable {
    public init() {}

    public nonisolated func perform(_ event: WordLoopHapticEvent) {
        Task { @MainActor in
            switch event {
            case .selection:
                UISelectionFeedbackGenerator().selectionChanged()
            case .impact:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .failure:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}
#endif
