import Foundation
import WordLoopAudio
import WordLoopContent
import WordLoopCore
import WordLoopProgress

struct StudyCourseClient: Sendable {
    var catalog: @Sendable () async throws -> CourseCatalog
    var course: @Sendable (CourseID) async throws -> Course

    static func live(repository: CourseRepository) -> Self {
        Self(
            catalog: { try await repository.catalog() },
            course: { try await repository.course(id: $0) }
        )
    }
}

struct StudyAudioClient: Sendable {
    var prepare: @Sendable (URL, URL?) async throws -> Void
    var play: @Sendable () async throws -> PlaybackRequestID
    var pause: @Sendable () async -> Void
    var stop: @Sendable () async -> Void
    var snapshot: @Sendable () async -> AudioPlaybackSnapshot
    var events: @Sendable () async -> AsyncStream<AudioPlayerEvent>

    static func live(player: AudioPlayer) -> Self {
        Self(
            prepare: { try await player.prepare(current: $0, next: $1) },
            play: { try await player.play() },
            pause: { await player.pause() },
            stop: { await player.stop() },
            snapshot: { await player.snapshot() },
            events: { await player.events() }
        )
    }
}

struct StudyProgressClient: Sendable {
    var snapshot: @Sendable (CourseID, StudyMode) async -> [EntryID: Int]
    var record: @Sendable (CourseID, StudyMode, EntryID) async -> Int
    var master: @Sendable (CourseID, StudyMode, EntryID) async -> Int

    static func temporary(repository: TemporaryProgressRepository) -> Self {
        Self(
            snapshot: { await repository.snapshot(courseID: $0, mode: $1) },
            record: { await repository.record(courseID: $0, mode: $1, entryID: $2) },
            master: { await repository.master(courseID: $0, mode: $1, entryID: $2) }
        )
    }
}

struct StudyClock: Sendable {
    var sleep: @Sendable (Duration) async throws -> Void

    static let live = Self(sleep: { try await Task.sleep(for: $0) })
}

struct StudyRandomClient: Sendable {
    var index: @Sendable (Int) -> Int

    static let live = Self(index: { upperBound in
        guard upperBound > 0 else { return 0 }
        return Int.random(in: 0..<upperBound)
    })
}
