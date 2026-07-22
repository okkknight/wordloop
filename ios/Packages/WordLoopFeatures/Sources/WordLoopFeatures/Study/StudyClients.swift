import Foundation
import WordLoopAudio
import WordLoopContent
import WordLoopCore
import WordLoopProgress
import WordLoopRealtime

struct StudyCourseClient: Sendable {
    var catalog: @Sendable () async throws -> CourseCatalog
    var course: @Sendable (CourseID) async throws -> Course
    var bundledCourseVersions: @Sendable () async -> [CourseID: Int] = { [:] }

    static func live(
        repository: CourseRepository,
        remoteCatalog: RemoteCatalogClient? = nil,
        installations: CourseInstallationStore? = nil,
        installedContentRootURL: URL? = nil
    ) -> Self {
        let descriptorCache = CourseDescriptorCache()
        return Self(
            catalog: {
                let bundled = try await repository.catalog()
                let catalog = if let remoteCatalog {
                    await remoteCatalog.catalog(merging: bundled)
                } else {
                    bundled
                }
                await descriptorCache.replace(with: catalog)
                return catalog
            },
            course: { id in
                if let descriptor = await descriptorCache.descriptor(for: id),
                   let installations,
                   let installedContentRootURL,
                   let installation = try? await installations.installation(for: id),
                   installation.status == .installed,
                   installation.contentVersion == descriptor.contentVersion {
                    return try BundledCourseSource(resourceRootURL: installedContentRootURL).loadCourse(descriptor: descriptor)
                }
                return try await repository.course(id: id)
            },
            bundledCourseVersions: {
                Dictionary(uniqueKeysWithValues: (try? await repository.catalog().courses.map { ($0.id, $0.contentVersion) }) ?? [])
            }
        )
    }
}

private actor CourseDescriptorCache {
    private var descriptors: [CourseID: CourseDescriptor] = [:]

    func replace(with catalog: CourseCatalog) {
        descriptors = Dictionary(uniqueKeysWithValues: catalog.courses.map { ($0.id, $0) })
    }

    func descriptor(for id: CourseID) -> CourseDescriptor? {
        descriptors[id]
    }
}

struct StudyDownloadClient: Sendable {
    var installations: @Sendable () async -> [CourseInstallation]
    var install: @Sendable (CourseDescriptor) async throws -> CourseInstallation

    static let unavailable = Self(installations: { [] }, install: { _ in
        throw CourseDownloadError.invalidCatalogURL
    })

    static func live(
        manager: CourseDownloadManager,
        installations: CourseInstallationStore,
        catalogURL: URL
    ) -> Self {
        Self(
            installations: { (try? await installations.all()) ?? [] },
            install: { descriptor in
                try await manager.install(descriptor: descriptor, catalogURL: catalogURL)
            }
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
    var configureForRepeat: @Sendable () async throws -> Void

    static func live(player: AudioPlayer) -> Self {
        Self(
            prepare: { try await player.prepare(current: $0, next: $1) },
            play: { try await player.play() },
            pause: { await player.pause() },
            stop: { await player.stop() },
            snapshot: { await player.snapshot() },
            events: { await player.events() },
            configureForRepeat: { try await player.configureForRepeat() }
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
    var resumeEntry: @Sendable (CourseID, StudyMode) async -> EntryID? = { _, _ in nil }
    var setResumeEntry: @Sendable (CourseID, StudyMode, EntryID?) async -> Void = { _, _, _ in }
    var synchronize: @Sendable (CourseID, StudyMode) async -> Void = { _, _ in }
    var synchronizeCompletions: @Sendable () async -> Void = {}

    static func temporary(repository: TemporaryProgressRepository) -> Self {
        Self(
            snapshot: { await repository.snapshot(courseID: $0, mode: $1) },
            record: { await repository.record(courseID: $0, mode: $1, entryID: $2) },
            master: { await repository.master(courseID: $0, mode: $1, entryID: $2) },
            reset: { await repository.reset(courseID: $0, mode: $1) },
            completions: { await repository.completions() },
            complete: { await repository.complete(courseID: $0, completionID: $1) },
            resumeEntry: { _, _ in nil },
            setResumeEntry: { _, _, _ in },
            synchronize: { _, _ in },
            synchronizeCompletions: {}
        )
    }

    static func persistent(
        repository: PersistentProgressRepository,
        session: ActiveStudySession
    ) -> Self {
        Self(
            snapshot: { courseID, mode in
                guard let userID = await session.userID else {
                    return [:]
                }
                // The local outbox is the source of truth for the current
                // turn. `StudyStore` requests remote reconciliation in a
                // separately cancellable task so it never blocks playback.
                let local = (try? await repository.snapshot(
                    userID: userID,
                    mode: mode,
                    courseID: courseID
                )) ?? [:]
                return local
            },
            record: { courseID, mode, entryID in
                guard let userID = await session.userID else {
                    return 0
                }
                let value = (try? await repository.record(userID: userID, mode: mode, courseID: courseID, entryID: entryID)) ?? 0
                Task { _ = try? await repository.flush(userID: userID, mode: mode, trigger: .networkRecovered) }
                return value
            },
            master: { courseID, mode, entryID in
                guard let userID = await session.userID else {
                    return 0
                }
                let value = (try? await repository.master(userID: userID, mode: mode, courseID: courseID, entryID: entryID)) ?? 0
                Task { _ = try? await repository.flush(userID: userID, mode: mode, trigger: .networkRecovered) }
                return value
            },
            reset: { courseID, mode in
                guard let userID = await session.userID else { return }
                try await repository.reset(userID: userID, mode: mode, courseID: courseID)
                Task { _ = try? await repository.flush(userID: userID, mode: mode, trigger: .networkRecovered) }
            },
            completions: {
                guard let userID = await session.userID else { return [:] }
                return (try? await repository.completions(userID: userID)) ?? [:]
            },
            complete: { courseID, completionID in
                guard let userID = await session.userID else { return 0 }
                let value = try await repository.complete(
                    userID: userID, courseID: courseID, clientEventID: completionID
                )
                Task { _ = try? await repository.flush(userID: userID, mode: .repeat, trigger: .networkRecovered) }
                return value
            },
            resumeEntry: { courseID, mode in
                guard let userID = await session.userID else { return nil }
                return await repository.resumeEntry(userID: userID, mode: mode, courseID: courseID)
            },
            setResumeEntry: { courseID, mode, entryID in
                guard let userID = await session.userID else { return }
                await repository.setResumeEntry(userID: userID, mode: mode, courseID: courseID, entryID: entryID)
            },
            synchronize: { courseID, mode in
                guard let userID = await session.userID else { return }
                _ = try? await repository.flush(userID: userID, mode: mode, trigger: .appBecameActive)
                _ = try? await repository.refresh(userID: userID, mode: mode, courseID: courseID)
            },
            synchronizeCompletions: {
                guard let userID = await session.userID else { return }
                _ = try? await repository.refreshCompletions(userID: userID, mode: .repeat)
            }
        )
    }
}

struct StudyRealtimeClient: @unchecked Sendable {
    var requestPermission: @Sendable () async -> Bool
    var connect: @Sendable (
        @escaping @Sendable (RealtimeTransportEvent) -> Void,
        @escaping @Sendable (RealtimePeerConnectionState) -> Void
    ) async throws -> Void
    var setMicrophoneEnabled: @Sendable (Bool) -> Void
    var close: @Sendable () -> Void

    static let unavailable = Self(
        requestPermission: { false },
        connect: { _, _ in throw RealtimeTransportError.unavailablePeerConnection },
        setMicrophoneEnabled: { _ in },
        close: {}
    )

    static func live(apiBaseURL: URL, session: ActiveStudySession) throws -> Self {
        let connection = LiveRealtimePeerConnection(
            sessionClient: try PronunciationSessionClient(baseURL: apiBaseURL)
        )
        let authorizer = LiveMicrophoneAuthorizer()
        return Self(
            requestPermission: { await authorizer.requestPermission() },
            connect: { event, state in
                connection.onEvent = event
                connection.onStateChange = state
                try await connection.connect(userID: await session.userID)
            },
            setMicrophoneEnabled: { connection.setMicrophoneEnabled($0) },
            close: { connection.close() }
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
