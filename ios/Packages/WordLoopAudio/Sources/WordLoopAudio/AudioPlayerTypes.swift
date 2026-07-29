import Foundation

public struct PlaybackRequestID: RawRepresentable, Hashable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

public enum AudioPlaybackPhase: Equatable, Sendable {
    case idle
    case prepared
    case playing
    case paused
    case stopped
    case finished
    case failed
}

public enum AudioPauseReason: Equatable, Sendable {
    case user
    case interruption
    case oldDeviceUnavailable
    case background
}

public enum AudioPlayerError: Error, Equatable, Sendable {
    case unsupportedPlatform
    case invalidLocalURL
    case fileMissing
    case nonRegularFile
    case couldNotPrepare
    case sessionActivationFailed
    case playbackStartFailed
    case decodeFailed
    case mediaServicesReset
    case invalidState
}

public struct AudioPlaybackSnapshot: Equatable, Sendable {
    public let phase: AudioPlaybackPhase
    public let currentURL: URL?
    public let nextURL: URL?
    public let requestID: PlaybackRequestID?
    public let pauseReason: AudioPauseReason?
    public let error: AudioPlayerError?

    public init(
        phase: AudioPlaybackPhase,
        currentURL: URL?,
        nextURL: URL?,
        requestID: PlaybackRequestID?,
        pauseReason: AudioPauseReason?,
        error: AudioPlayerError?
    ) {
        self.phase = phase
        self.currentURL = currentURL
        self.nextURL = nextURL
        self.requestID = requestID
        self.pauseReason = pauseReason
        self.error = error
    }
}

public enum AudioPlayerEvent: Equatable, Sendable {
    case stateChanged(AudioPlaybackSnapshot)
    case preloadFailed(URL, AudioPlayerError)
}
