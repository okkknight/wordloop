import WordLoopAudio
import WordLoopCore

public enum StudyPhase: Equatable, Sendable {
    case idle
    case loading
    case ready
    case failed
}

public enum ListenPhase: Equatable, Sendable {
    case idle
    case preparing
    case playing
    case paused
    case waiting
    case failed
}

public struct ListenSessionGeneration: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

public struct StudyState: Equatable, Sendable {
    public var phase: StudyPhase
    public var listenPhase: ListenPhase
    public var selectedCourseID: CourseID?
    public var currentEntryID: EntryID?
    public var nextEntryID: EntryID?
    public var isAutoplayEnabled: Bool
    public var listenGeneration: ListenSessionGeneration
    public var activePlaybackRequestID: PlaybackRequestID?
    public var courseExhausted: Bool

    public init(
        phase: StudyPhase = .idle,
        listenPhase: ListenPhase = .idle,
        selectedCourseID: CourseID? = nil,
        currentEntryID: EntryID? = nil,
        nextEntryID: EntryID? = nil,
        isAutoplayEnabled: Bool = false,
        listenGeneration: ListenSessionGeneration = .init(rawValue: 0),
        activePlaybackRequestID: PlaybackRequestID? = nil,
        courseExhausted: Bool = false
    ) {
        self.phase = phase
        self.listenPhase = listenPhase
        self.selectedCourseID = selectedCourseID
        self.currentEntryID = currentEntryID
        self.nextEntryID = nextEntryID
        self.isAutoplayEnabled = isAutoplayEnabled
        self.listenGeneration = listenGeneration
        self.activePlaybackRequestID = activePlaybackRequestID
        self.courseExhausted = courseExhausted
    }
}
