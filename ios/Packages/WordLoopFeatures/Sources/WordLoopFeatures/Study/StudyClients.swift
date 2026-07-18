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
    var reset: @Sendable (CourseID, StudyMode) async throws -> Void
    var completions: @Sendable () async -> [CourseID: Int]
    var complete: @Sendable (CourseID, String) async throws -> Int

    static func temporary(repository: TemporaryProgressRepository) -> Self {
        Self(
            snapshot: { await repository.snapshot(courseID: $0, mode: $1) },
            record: { await repository.record(courseID: $0, mode: $1, entryID: $2) },
            master: { await repository.master(courseID: $0, mode: $1, entryID: $2) },
            reset: { await repository.reset(courseID: $0, mode: $1) },
            completions: { await repository.completions() },
            complete: { await repository.complete(courseID: $0, completionID: $1) }
        )
    }

    static func persistent(
        repository: PersistentProgressRepository,
        session: ActiveStudySession,
        completionFallback: TemporaryProgressRepository
    ) -> Self {
        Self(
            snapshot: { courseID, mode in
                guard let userID = await session.userID else {
                    return await completionFallback.snapshot(courseID: courseID, mode: mode)
                }
                _ = try? await repository.flush(userID: userID, mode: mode, trigger: .appBecameActive)
                if let remote = try? await repository.refresh(userID: userID, mode: mode, courseID: courseID) {
                    return remote
                }
                return (try? await repository.snapshot(userID: userID, mode: mode, courseID: courseID)) ?? [:]
            },
            record: { courseID, mode, entryID in
                guard let userID = await session.userID else {
                    return await completionFallback.record(courseID: courseID, mode: mode, entryID: entryID)
                }
                let value = (try? await repository.record(userID: userID, mode: mode, courseID: courseID, entryID: entryID)) ?? 0
                Task { _ = try? await repository.flush(userID: userID, mode: mode, trigger: .networkRecovered) }
                return value
            },
            master: { courseID, mode, entryID in
                guard let userID = await session.userID else {
                    return await completionFallback.master(courseID: courseID, mode: mode, entryID: entryID)
                }
                let value = (try? await repository.master(userID: userID, mode: mode, courseID: courseID, entryID: entryID)) ?? 0
                Task { _ = try? await repository.flush(userID: userID, mode: mode, trigger: .networkRecovered) }
                return value
            },
            reset: { await completionFallback.reset(courseID: $0, mode: $1) },
            completions: { await completionFallback.completions() },
            complete: { await completionFallback.complete(courseID: $0, completionID: $1) }
        )
    }
}

actor ActiveStudySession {
    private(set) var userID: String?

    func activate(_ userID: String) { self.userID = userID }
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
