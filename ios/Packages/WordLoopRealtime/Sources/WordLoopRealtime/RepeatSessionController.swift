import Foundation

public enum RepeatSessionPhase: Equatable, Sendable {
    case idle, connecting, ready, playing, armed, speaking, scoring, passed, retry, paused, recoverableError
}

public enum RepeatSessionAction: Equatable, Sendable {
    case enableMicrophone
    case disableMicrophone
    case score(turnID: UInt64, itemID: String, transcript: String)
}

/// Small state machine copied from the Web invariants: a new turn invalidates
/// every old event; input is accepted only after playback and for its VAD item.
public struct RepeatSessionController: Sendable {
    public private(set) var phase: RepeatSessionPhase = .idle
    public private(set) var turnID: UInt64 = 0
    public private(set) var itemID: String?

    public init() {}

    @discardableResult
    public mutating func beginTurn() -> UInt64 {
        turnID &+= 1
        itemID = nil
        phase = .playing
        return turnID
    }

    public mutating func connected() {
        guard phase == .connecting || phase == .idle else { return }
        phase = .ready
    }

    public mutating func playbackFinished(turnID: UInt64) -> RepeatSessionAction? {
        guard turnID == self.turnID, phase == .playing else { return nil }
        phase = .armed
        return .enableMicrophone
    }

    public mutating func receive(_ event: RealtimeTransportEvent, turnID: UInt64) -> RepeatSessionAction? {
        guard turnID == self.turnID else { return nil }
        switch event {
        case let .speechStarted(eventItemID):
            guard phase == .armed else { return nil }
            itemID = eventItemID
            phase = .speaking
            return nil
        case let .speechStopped(eventItemID), let .audioCommitted(eventItemID):
            guard phase == .speaking, eventItemID == nil || eventItemID == itemID else { return nil }
            phase = .scoring
            return .disableMicrophone
        case let .transcriptionCompleted(eventItemID, transcript):
            guard phase == .scoring, eventItemID == itemID else { return nil }
            return .score(turnID: turnID, itemID: eventItemID, transcript: transcript)
        case let .transcriptionFailed(eventItemID):
            guard (phase == .speaking || phase == .scoring), eventItemID == nil || eventItemID == itemID else { return nil }
            phase = .retry
            return .disableMicrophone
        }
    }

    public mutating func scored(turnID: UInt64, passed: Bool) {
        guard turnID == self.turnID, phase == .scoring else { return }
        phase = passed ? .passed : .retry
    }

    public mutating func pause() -> RepeatSessionAction? {
        guard phase != .idle && phase != .paused else { return nil }
        turnID &+= 1
        itemID = nil
        phase = .paused
        return .disableMicrophone
    }

    public mutating func invalidate() -> RepeatSessionAction? {
        guard phase != .idle else { return nil }
        turnID &+= 1
        itemID = nil
        phase = .idle
        return .disableMicrophone
    }
}
