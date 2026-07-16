import Foundation
import XCTest
import WordLoopAudio
import WordLoopCore
@testable import WordLoopFeatures

@MainActor
final class StudyStoreTests: XCTestCase {
    func testStartLoadsDefaultSequentialEntryInRepeatWithoutPlayingOrRecording() async {
        let harness = makeHarness()

        await harness.store.start()

        XCTAssertEqual(harness.store.state.phase, .ready)
        XCTAssertEqual(harness.store.state.selectedCourseID, harness.primary.id)
        XCTAssertEqual(harness.store.state.currentEntryID, harness.primary.entries[0].id)
        XCTAssertEqual(harness.store.state.listenPhase, .idle)
        XCTAssertEqual(harness.store.shellStore.state.mode, .repeat)
        assertEqual(await harness.audio.prepareCalls(), [])
        assertEqual(await harness.audio.playCallCount(), 0)
        assertEqual(await harness.progress.counts(courseID: harness.primary.id, mode: .listen), [:])
        assertEqual(await harness.progress.counts(courseID: harness.primary.id, mode: .repeat), [:])
    }

    func testEnteringListenRecordsAndPlaysCurrentAndNextWhileReplayOnlyIssuesANewToken() async {
        let harness = makeHarness()
        await harness.store.start()

        await harness.store.selectMode(.listen)

        let firstToken = try! XCTUnwrap(harness.store.state.activePlaybackRequestID)
        XCTAssertEqual(harness.store.state.listenPhase, .playing)
        XCTAssertEqual(harness.store.state.currentEntryID, harness.primary.entries[0].id)
        XCTAssertEqual(harness.store.state.nextEntryID, harness.primary.entries[1].id)
        assertEqual(
            await harness.audio.prepareCalls(),
            [.init(current: harness.primary.entries[0].audioURL, next: harness.primary.entries[1].audioURL)]
        )
        assertEqual(
            await harness.progress.counts(courseID: harness.primary.id, mode: .listen),
            [harness.primary.entries[0].id: 1]
        )

        await harness.store.playCurrent()

        let replayToken = try! XCTUnwrap(harness.store.state.activePlaybackRequestID)
        XCTAssertNotEqual(replayToken, firstToken)
        assertEqual(await harness.audio.playCallCount(), 2)
        assertEqual(
            await harness.progress.counts(courseID: harness.primary.id, mode: .listen),
            [harness.primary.entries[0].id: 1]
        )
    }

    func testManualNextStartsExactlyOneNewLearningRound() async {
        let harness = makeHarness()
        await enterListen(harness)

        await harness.store.next()

        XCTAssertEqual(harness.store.state.currentEntryID, harness.primary.entries[1].id)
        XCTAssertEqual(harness.store.state.nextEntryID, harness.primary.entries[2].id)
        XCTAssertEqual(harness.store.state.listenPhase, .playing)
        assertEqual(
            await harness.progress.counts(courseID: harness.primary.id, mode: .listen),
            [harness.primary.entries[0].id: 1, harness.primary.entries[1].id: 1]
        )
        assertEqual(await harness.audio.playCallCount(), 2)
    }

    func testMatchingFinishWaitsForControlled500MillisecondsAndAdvancesExactlyOnce() async {
        let harness = makeHarness()
        await enterListen(harness)
        await harness.store.toggleAutoplay()
        let token = try! XCTUnwrap(harness.store.state.activePlaybackRequestID)

        harness.audio.emit(.stateChanged(snapshot(
            phase: .finished,
            currentURL: harness.primary.entries[0].audioURL,
            requestID: token
        )))
        await eventually { harness.store.state.listenPhase == .waiting }
        await eventually { await harness.clock.pendingCount() == 1 }

        assertEqual(await harness.clock.requestedDurations(), [.milliseconds(500)])
        XCTAssertEqual(harness.store.state.currentEntryID, harness.primary.entries[0].id)

        await harness.clock.advanceAll()
        await eventually { harness.store.state.currentEntryID == harness.primary.entries[1].id }
        for _ in 0..<20 { await Task.yield() }

        assertEqual(await harness.audio.playCallCount(), 2)
        assertEqual(
            await harness.progress.counts(courseID: harness.primary.id, mode: .listen),
            [harness.primary.entries[0].id: 1, harness.primary.entries[1].id: 1]
        )
    }

    func testTurningAutoplayOffCancelsWaitingAndDoesNotSkipTheUnplayedItem() async {
        let harness = makeHarness()
        await enterListen(harness)
        await harness.store.toggleAutoplay()
        let token = try! XCTUnwrap(harness.store.state.activePlaybackRequestID)
        harness.audio.emit(.stateChanged(snapshot(
            phase: .finished,
            currentURL: harness.primary.entries[0].audioURL,
            requestID: token
        )))
        await eventually { harness.store.state.listenPhase == .waiting }

        await harness.store.toggleAutoplay()
        XCTAssertFalse(harness.store.state.isAutoplayEnabled)
        XCTAssertEqual(harness.store.state.listenPhase, .idle)
        let generationAfterCancel = harness.store.state.listenGeneration
        await harness.clock.advanceAll()
        for _ in 0..<20 { await Task.yield() }

        XCTAssertEqual(harness.store.state.listenGeneration, generationAfterCancel)
        XCTAssertEqual(harness.store.state.currentEntryID, harness.primary.entries[0].id)
        assertEqual(await harness.audio.playCallCount(), 1)

        await harness.store.toggleAutoplay()
        XCTAssertTrue(harness.store.state.isAutoplayEnabled)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(harness.store.state.currentEntryID, harness.primary.entries[0].id)
        assertEqual(await harness.audio.playCallCount(), 1)
    }

    func testCurrentFailureDisablesAutoplayAndKeepsEntryAvailableForReplayOrNext() async {
        let harness = makeHarness()
        await enterListen(harness)
        await harness.store.toggleAutoplay()
        let token = try! XCTUnwrap(harness.store.state.activePlaybackRequestID)

        harness.audio.emit(.stateChanged(snapshot(
            phase: .failed,
            currentURL: harness.primary.entries[0].audioURL,
            requestID: token,
            error: .decodeFailed
        )))
        await eventually { harness.store.state.listenPhase == .failed }

        XCTAssertFalse(harness.store.state.isAutoplayEnabled)
        XCTAssertEqual(harness.store.state.currentEntryID, harness.primary.entries[0].id)
        XCTAssertNil(harness.store.state.activePlaybackRequestID)

        await harness.store.playCurrent()
        XCTAssertEqual(harness.store.state.currentEntryID, harness.primary.entries[0].id)
        XCTAssertEqual(harness.store.state.listenPhase, .playing)
        assertEqual(await harness.audio.playCallCount(), 2)

        await harness.store.next()
        XCTAssertEqual(harness.store.state.currentEntryID, harness.primary.entries[1].id)
    }

    func testOldTokenOldTimerAndFastCourseOrNextTransitionsAreSilent() async {
        let harness = makeHarness()
        await enterListen(harness)
        let firstToken = try! XCTUnwrap(harness.store.state.activePlaybackRequestID)

        await harness.store.next()
        let secondToken = try! XCTUnwrap(harness.store.state.activePlaybackRequestID)
        harness.audio.emit(.stateChanged(snapshot(
            phase: .finished,
            currentURL: harness.primary.entries[0].audioURL,
            requestID: firstToken
        )))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(harness.store.state.currentEntryID, harness.primary.entries[1].id)
        XCTAssertEqual(harness.store.state.activePlaybackRequestID, secondToken)
        XCTAssertEqual(harness.store.state.listenPhase, .playing)

        await harness.store.toggleAutoplay()
        harness.audio.emit(.stateChanged(snapshot(
            phase: .finished,
            currentURL: harness.primary.entries[1].audioURL,
            requestID: secondToken
        )))
        await eventually { harness.store.state.listenPhase == .waiting }
        await eventually { await harness.clock.pendingCount() == 1 }

        await harness.store.selectCourse(harness.secondary.id.rawValue)
        let secondaryToken = try! XCTUnwrap(harness.store.state.activePlaybackRequestID)
        XCTAssertEqual(harness.store.state.selectedCourseID, harness.secondary.id)
        XCTAssertEqual(harness.store.state.currentEntryID, harness.secondary.entries[0].id)
        await harness.clock.advanceAll()
        harness.audio.emit(.stateChanged(snapshot(
            phase: .failed,
            currentURL: harness.primary.entries[1].audioURL,
            requestID: secondToken,
            error: .decodeFailed
        )))
        for _ in 0..<30 { await Task.yield() }

        XCTAssertEqual(harness.store.state.selectedCourseID, harness.secondary.id)
        XCTAssertEqual(harness.store.state.currentEntryID, harness.secondary.entries[0].id)
        XCTAssertEqual(harness.store.state.activePlaybackRequestID, secondaryToken)
        XCTAssertEqual(harness.store.state.listenPhase, .playing)
    }

    func testBackgroundDuringPlayingOrWaitingCancelsSessionAndNeverAutoResumes() async {
        let playingHarness = makeHarness()
        await enterListen(playingHarness)
        let playingEntry = playingHarness.store.state.currentEntryID

        await playingHarness.store.setApplicationActive(false)
        XCTAssertEqual(playingHarness.store.state.listenPhase, .paused)
        XCTAssertNil(playingHarness.store.state.activePlaybackRequestID)
        assertEqual(await playingHarness.audio.pauseCallCount(), 1)
        await playingHarness.store.setApplicationActive(true)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(playingHarness.store.state.currentEntryID, playingEntry)
        assertEqual(await playingHarness.audio.playCallCount(), 1)

        let waitingHarness = makeHarness()
        await enterListen(waitingHarness)
        await waitingHarness.store.toggleAutoplay()
        let token = try! XCTUnwrap(waitingHarness.store.state.activePlaybackRequestID)
        waitingHarness.audio.emit(.stateChanged(snapshot(
            phase: .finished,
            currentURL: waitingHarness.primary.entries[0].audioURL,
            requestID: token
        )))
        await eventually { waitingHarness.store.state.listenPhase == .waiting }
        await waitingHarness.store.setApplicationActive(false)
        XCTAssertEqual(waitingHarness.store.state.listenPhase, .paused)
        await waitingHarness.clock.advanceAll()
        await waitingHarness.store.setApplicationActive(true)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(waitingHarness.store.state.currentEntryID, waitingHarness.primary.entries[0].id)
        assertEqual(await waitingHarness.audio.playCallCount(), 1)
    }

    func testOnlyCurrentCanProgressFromOneToThreeThenBecomesExhausted() async {
        let harness = makeHarness(primaryEntryCount: 1)
        await enterListen(harness)
        let onlyID = harness.primary.entries[0].id

        assertEqual(await harness.progress.counts(courseID: harness.primary.id, mode: .listen), [onlyID: 1])
        await harness.store.next()
        assertEqual(await harness.progress.counts(courseID: harness.primary.id, mode: .listen), [onlyID: 2])
        XCTAssertFalse(harness.store.state.courseExhausted)
        await harness.store.next()
        assertEqual(await harness.progress.counts(courseID: harness.primary.id, mode: .listen), [onlyID: 3])
        XCTAssertTrue(harness.store.state.courseExhausted)

        let playCountAtMastery = await harness.audio.playCallCount()
        await harness.store.next()
        XCTAssertTrue(harness.store.state.courseExhausted)
        assertEqual(await harness.audio.playCallCount(), playCountAtMastery)
        assertEqual(await harness.progress.counts(courseID: harness.primary.id, mode: .listen), [onlyID: 3])
    }

    func testSwitchingToRepeatStopsListenWithoutRecordingRepeatProgress() async {
        let harness = makeHarness()
        await enterListen(harness)
        let listenCounts = await harness.progress.counts(courseID: harness.primary.id, mode: .listen)
        let generation = harness.store.state.listenGeneration

        await harness.store.selectMode(.repeat)

        XCTAssertEqual(harness.store.shellStore.state.mode, .repeat)
        XCTAssertEqual(harness.store.state.listenPhase, .idle)
        XCTAssertNil(harness.store.state.activePlaybackRequestID)
        XCTAssertGreaterThan(harness.store.state.listenGeneration.rawValue, generation.rawValue)
        assertEqual(await harness.audio.stopCallCount(), 3)
        assertEqual(await harness.progress.counts(courseID: harness.primary.id, mode: .listen), listenCounts)
        assertEqual(await harness.progress.counts(courseID: harness.primary.id, mode: .repeat), [:])
    }

    private func enterListen(_ harness: StudyHarness) async {
        await harness.store.start()
        await harness.store.selectMode(.listen)
        XCTAssertEqual(harness.store.state.listenPhase, .playing)
    }

    private func makeHarness(primaryEntryCount: Int = 3) -> StudyHarness {
        let primary = makeCourse(id: "course-one", entryCount: primaryEntryCount)
        let secondary = makeCourse(id: "course-two", entryCount: 3)
        let collection = CourseCollectionDescriptor(
            id: CourseCollectionID(rawValue: "collection-one")!,
            label: "COLLECTION",
            title: "Collection",
            subtitle: "Fixture"
        )
        let catalog = CourseCatalog(
            schemaVersion: 1,
            generatedAt: "fixture",
            defaultCourseID: primary.id,
            collections: [collection],
            courses: [primary.descriptor, secondary.descriptor]
        )
        let audio = TestAudio()
        let progress = TestProgress()
        let clock = TestClock()
        let coursesByID = [primary.id: primary, secondary.id: secondary]
        let store = StudyStore(
            courses: StudyCourseClient(
                catalog: { catalog },
                course: { id in
                    guard let course = coursesByID[id] else { throw TestError.missingCourse }
                    return course
                }
            ),
            audio: audio.client,
            progress: progress.client,
            clock: clock.client,
            random: StudyRandomClient(index: { _ in 0 })
        )
        return StudyHarness(
            store: store,
            primary: primary,
            secondary: secondary,
            audio: audio,
            progress: progress,
            clock: clock
        )
    }

    private func makeCourse(id: String, entryCount: Int) -> Course {
        let courseID = CourseID(rawValue: id)!
        let collectionID = CourseCollectionID(rawValue: "collection-one")!
        let descriptor = CourseDescriptor(
            id: courseID,
            collectionID: collectionID,
            title: id,
            subtitle: "Fixture",
            description: "Fixture course",
            kind: .sentence,
            practiceOrder: .sequential,
            contentVersion: 1,
            minimumAppVersion: "1.0.0",
            manifestLocation: "courses/\(id)/course.json",
            manifestSHA256: String(repeating: "a", count: 64),
            downloadSize: entryCount,
            availability: .available
        )
        let entries = (1...entryCount).map { index in
            CourseEntry(
                id: EntryID(rawValue: "\(id)-entry-\(index)")!,
                text: "Entry \(index)",
                translation: "Translation \(index)",
                phonetic: nil,
                highlights: [],
                audioURL: URL(fileURLWithPath: "/tmp/\(id)-entry-\(index).m4a"),
                durationMilliseconds: 1_000
            )
        }
        return Course(descriptor: descriptor, entries: entries)
    }

    private func snapshot(
        phase: AudioPlaybackPhase,
        currentURL: URL,
        requestID: PlaybackRequestID?,
        error: AudioPlayerError? = nil
    ) -> AudioPlaybackSnapshot {
        AudioPlaybackSnapshot(
            phase: phase,
            currentURL: currentURL,
            nextURL: nil,
            requestID: requestID,
            pauseReason: nil,
            error: error
        )
    }

    private func eventually(
        _ condition: @MainActor () async -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<500 {
            if await condition() { return }
            await Task.yield()
        }
        XCTFail("Condition did not become true", file: file, line: line)
    }

    private func assertEqual<T: Equatable>(
        _ actual: T,
        _ expected: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual, expected, file: file, line: line)
    }
}

@MainActor
private struct StudyHarness {
    let store: StudyStore
    let primary: Course
    let secondary: Course
    let audio: TestAudio
    let progress: TestProgress
    let clock: TestClock
}

private enum TestError: Error {
    case missingCourse
}

private struct PrepareCall: Equatable, Sendable {
    let current: URL
    let next: URL?
}

private final class TestAudio: @unchecked Sendable {
    private let recorder = TestAudioRecorder()
    private let continuation: AsyncStream<AudioPlayerEvent>.Continuation
    private let stream: AsyncStream<AudioPlayerEvent>

    init() {
        let pair = AsyncStream<AudioPlayerEvent>.makeStream()
        stream = pair.stream
        continuation = pair.continuation
    }

    var client: StudyAudioClient {
        StudyAudioClient(
            prepare: { [recorder] current, next in await recorder.prepare(current, next) },
            play: { [recorder] in await recorder.play() },
            pause: { [recorder] in await recorder.pause() },
            stop: { [recorder] in await recorder.stop() },
            snapshot: { [recorder] in await recorder.snapshot() },
            events: { [stream] in stream }
        )
    }

    func emit(_ event: AudioPlayerEvent) {
        continuation.yield(event)
    }

    func prepareCalls() async -> [PrepareCall] { await recorder.prepareCalls }
    func playCallCount() async -> Int { await recorder.playCallCount }
    func pauseCallCount() async -> Int { await recorder.pauseCallCount }
    func stopCallCount() async -> Int { await recorder.stopCallCount }
}

private actor TestAudioRecorder {
    private(set) var prepareCalls: [PrepareCall] = []
    private(set) var playCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var stopCallCount = 0
    private var latestSnapshot = AudioPlaybackSnapshot(
        phase: .idle,
        currentURL: nil,
        nextURL: nil,
        requestID: nil,
        pauseReason: nil,
        error: nil
    )

    func prepare(_ current: URL, _ next: URL?) {
        prepareCalls.append(.init(current: current, next: next))
        latestSnapshot = AudioPlaybackSnapshot(
            phase: .prepared,
            currentURL: current,
            nextURL: next,
            requestID: nil,
            pauseReason: nil,
            error: nil
        )
    }

    func play() -> PlaybackRequestID {
        playCallCount += 1
        let token = PlaybackRequestID(rawValue: UUID())
        latestSnapshot = AudioPlaybackSnapshot(
            phase: .playing,
            currentURL: latestSnapshot.currentURL,
            nextURL: latestSnapshot.nextURL,
            requestID: token,
            pauseReason: nil,
            error: nil
        )
        return token
    }

    func pause() { pauseCallCount += 1 }

    func stop() {
        stopCallCount += 1
        latestSnapshot = AudioPlaybackSnapshot(
            phase: .stopped,
            currentURL: nil,
            nextURL: nil,
            requestID: nil,
            pauseReason: nil,
            error: nil
        )
    }

    func snapshot() -> AudioPlaybackSnapshot { latestSnapshot }
}

private actor TestProgress {
    private struct Key: Hashable, Sendable {
        let courseID: CourseID
        let mode: StudyMode
    }

    private var storage: [Key: [EntryID: Int]] = [:]

    nonisolated var client: StudyProgressClient {
        StudyProgressClient(
            snapshot: { [weak self] courseID, mode in
                await self?.counts(courseID: courseID, mode: mode) ?? [:]
            },
            record: { [weak self] courseID, mode, entryID in
                await self?.record(courseID: courseID, mode: mode, entryID: entryID) ?? 0
            },
            master: { [weak self] courseID, mode, entryID in
                await self?.master(courseID: courseID, mode: mode, entryID: entryID) ?? 0
            }
        )
    }

    func counts(courseID: CourseID, mode: StudyMode) -> [EntryID: Int] {
        storage[Key(courseID: courseID, mode: mode), default: [:]]
    }

    private func record(courseID: CourseID, mode: StudyMode, entryID: EntryID) -> Int {
        let key = Key(courseID: courseID, mode: mode)
        let count = min(3, storage[key, default: [:]][entryID, default: 0] + 1)
        storage[key, default: [:]][entryID] = count
        return count
    }

    private func master(courseID: CourseID, mode: StudyMode, entryID: EntryID) -> Int {
        let key = Key(courseID: courseID, mode: mode)
        storage[key, default: [:]][entryID] = 3
        return 3
    }
}

private actor TestClock {
    private struct Sleeper {
        let id: UUID
        let continuation: CheckedContinuation<Void, any Error>
    }

    private var sleepers: [Sleeper] = []
    private var cancelledIDs: Set<UUID> = []
    private var durations: [Duration] = []

    nonisolated var client: StudyClock {
        StudyClock(sleep: { [weak self] duration in
            guard let self else { throw CancellationError() }
            try await self.sleep(duration)
        })
    }

    func sleep(_ duration: Duration) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                durations.append(duration)
                if cancelledIDs.remove(id) != nil || Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    sleepers.append(.init(id: id, continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    func pendingCount() -> Int { sleepers.count }
    func requestedDurations() -> [Duration] { durations }

    func advanceAll() {
        let active = sleepers
        sleepers.removeAll()
        for sleeper in active {
            sleeper.continuation.resume()
        }
    }

    private func cancel(_ id: UUID) {
        if let index = sleepers.firstIndex(where: { $0.id == id }) {
            let sleeper = sleepers.remove(at: index)
            sleeper.continuation.resume(throwing: CancellationError())
        } else {
            cancelledIDs.insert(id)
        }
    }
}
