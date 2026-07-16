import Darwin
import Foundation
import XCTest
@testable import WordLoopAudio

final class WordLoopAudioTests: XCTestCase {
    func testModuleIsAvailableAndInitialSnapshotIsIdle() async throws {
        XCTAssertEqual(WordLoopAudioModule.name, "WordLoopAudio")
        let harness = try AudioHarness()

        let snapshot = await harness.player.snapshot()
        XCTAssertEqual(
            snapshot,
            AudioPlaybackSnapshot(
                phase: .idle,
                currentURL: nil,
                nextURL: nil,
                requestID: nil,
                pauseReason: nil,
                error: nil
            )
        )
    }

    func testPrepareCurrentAndNextDoesNotActivateSession() async throws {
        let harness = try AudioHarness()
        try await harness.player.prepare(current: harness.files.a, next: harness.files.b)

        let snapshot = await harness.player.snapshot()
        XCTAssertEqual(snapshot.phase, .prepared)
        XCTAssertEqual(snapshot.currentURL, harness.files.a.standardizedFileURL)
        XCTAssertEqual(snapshot.nextURL, harness.files.b.standardizedFileURL)
        XCTAssertNil(snapshot.requestID)
        XCTAssertEqual(harness.factory.engines.count, 2)
        XCTAssertEqual(harness.factory.engines.map(\.prepareCount), [1, 1])
        let preparedEngineCount = await harness.player.preparedEngineCount()
        XCTAssertEqual(preparedEngineCount, 2)
        XCTAssertTrue(harness.session.calls.isEmpty)
    }

    func testPrepareWithNilReleasesPreviousNext() async throws {
        let harness = try AudioHarness()
        try await harness.player.prepare(current: harness.files.a, next: harness.files.b)
        let oldNext = try XCTUnwrap(harness.factory.engine(for: harness.files.b))

        try await harness.player.prepare(current: harness.files.a, next: nil)

        let snapshot = await harness.player.snapshot()
        XCTAssertNil(snapshot.nextURL)
        XCTAssertTrue(oldNext.isStopped)
        XCTAssertGreaterThanOrEqual(oldNext.clearCallbacksCount, 1)
    }

    func testNextPromotionReusesPreparedEngineAndOnlyCreatesFollowingEngine() async throws {
        let harness = try AudioHarness()
        try await harness.player.prepare(current: harness.files.a, next: harness.files.b)
        let oldCurrent = try XCTUnwrap(harness.factory.engine(for: harness.files.a))
        let promoted = try XCTUnwrap(harness.factory.engine(for: harness.files.b))
        promoted.currentTime = 8.5

        try await harness.player.prepare(current: harness.files.b, next: harness.files.c)

        XCTAssertEqual(harness.factory.engines.count, 3)
        let preparedEngineCount = await harness.player.preparedEngineCount()
        XCTAssertEqual(preparedEngineCount, 2)
        XCTAssertTrue(oldCurrent.isStopped)
        XCTAssertEqual(promoted.currentTime, 0)
        XCTAssertTrue(harness.factory.engine(for: harness.files.b) === promoted)
        let snapshot = await harness.player.snapshot()
        XCTAssertEqual(snapshot.currentURL, harness.files.b.standardizedFileURL)
        XCTAssertEqual(snapshot.nextURL, harness.files.c.standardizedFileURL)
    }

    func testSameCurrentStartsANewRoundAtZeroAndInvalidatesOldCallback() async throws {
        let harness = try AudioHarness()
        try await harness.player.prepare(current: harness.files.a, next: harness.files.b)
        _ = try await harness.player.play()
        let engine = try XCTUnwrap(harness.factory.engine(for: harness.files.a))
        engine.currentTime = 4.25
        let lateFinish = engine.queuedFinish()

        try await harness.player.prepare(current: harness.files.a, next: harness.files.c)
        await lateFinish()

        XCTAssertEqual(engine.currentTime, 0)
        let snapshot = await harness.player.snapshot()
        XCTAssertEqual(snapshot.phase, .prepared)
        XCTAssertEqual(harness.factory.engines.count, 3)
    }

    func testCurrentPrepareFailureClearsSlotsAndFails() async throws {
        let harness = try AudioHarness()
        try await harness.player.prepare(current: harness.files.a, next: harness.files.b)
        harness.factory.prepareFailures.insert(harness.files.c.standardizedFileURL)

        await assertThrows(.couldNotPrepare) {
            try await harness.player.prepare(current: harness.files.c, next: nil)
        }

        let snapshot = await harness.player.snapshot()
        XCTAssertEqual(snapshot.phase, .failed)
        XCTAssertEqual(snapshot.error, .couldNotPrepare)
        XCTAssertNil(snapshot.currentURL)
        XCTAssertNil(snapshot.nextURL)
    }

    func testCurrentEngineCreationFailureIsTypedAndLeavesNoPreparedEngine() async throws {
        let harness = try AudioHarness()
        harness.factory.creationFailures.insert(harness.files.a.standardizedFileURL)

        await assertThrows(.couldNotPrepare) {
            try await harness.player.prepare(current: harness.files.a, next: harness.files.b)
        }

        let snapshot = await harness.player.snapshot()
        XCTAssertEqual(snapshot.phase, .failed)
        XCTAssertEqual(snapshot.error, .couldNotPrepare)
        let preparedEngineCount = await harness.player.preparedEngineCount()
        XCTAssertEqual(preparedEngineCount, 0)
        XCTAssertTrue(harness.session.calls.isEmpty)
    }

    func testReplacingNextKeepsExactlyTwoPreparedEngines() async throws {
        let harness = try AudioHarness()
        try await harness.player.prepare(current: harness.files.a, next: harness.files.b)
        let oldNext = try XCTUnwrap(harness.factory.engine(for: harness.files.b))

        try await harness.player.prepare(current: harness.files.a, next: harness.files.c)

        XCTAssertTrue(oldNext.isStopped)
        let preparedEngineCount = await harness.player.preparedEngineCount()
        XCTAssertEqual(preparedEngineCount, 2)
        let snapshot = await harness.player.snapshot()
        XCTAssertEqual(snapshot.currentURL, harness.files.a.standardizedFileURL)
        XCTAssertEqual(snapshot.nextURL, harness.files.c.standardizedFileURL)
    }

    func testNextPrepareFailureDoesNotBlockCurrentAndEmitsPreloadFailure() async throws {
        let harness = try AudioHarness()
        harness.factory.prepareFailures.insert(harness.files.b.standardizedFileURL)
        let recorder = await EventRecorder(stream: harness.player.events())

        try await harness.player.prepare(current: harness.files.a, next: harness.files.b)

        let snapshot = await harness.player.snapshot()
        XCTAssertEqual(snapshot.phase, .prepared)
        XCTAssertEqual(snapshot.currentURL, harness.files.a.standardizedFileURL)
        XCTAssertNil(snapshot.nextURL)
        let events = await recorder.waitForCount(2)
        XCTAssertEqual(events[0], .preloadFailed(harness.files.b, .couldNotPrepare))
        XCTAssertEqual(events[1], .stateChanged(snapshot))
    }

    func testRejectsRemoteMissingSymlinkAndFIFO() async throws {
        let harness = try AudioHarness()
        let remote = try XCTUnwrap(URL(string: "https://example.com/audio.m4a"))
        await assertPrepareError(.invalidLocalURL, url: remote, player: harness.player)
        await assertPrepareError(.fileMissing, url: harness.files.missing, player: harness.player)
        await assertPrepareError(.nonRegularFile, url: harness.files.symlink, player: harness.player)
        await assertPrepareError(.nonRegularFile, url: harness.files.fifo, player: harness.player)
    }

    func testPlayFinishAndReplayUseNewTokensAndReplayFromZero() async throws {
        let harness = try AudioHarness()
        try await harness.player.prepare(current: harness.files.a, next: harness.files.b)
        let engine = try XCTUnwrap(harness.factory.engine(for: harness.files.a))

        let first = try await harness.player.play()
        let playing = await harness.player.snapshot()
        XCTAssertEqual(playing.requestID, first)
        await engine.fireFinish()
        let finished = await harness.player.snapshot()
        XCTAssertEqual(finished.phase, .finished)
        XCTAssertEqual(finished.requestID, first)
        XCTAssertEqual(harness.session.calls, [.configure, .activate, .deactivate])

        engine.currentTime = 11
        let second = try await harness.player.play()
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(engine.currentTime, 0)
        let replaying = await harness.player.snapshot()
        XCTAssertEqual(replaying.phase, .playing)
    }

    func testFinishAndDecodeFailureSettleExactlyOnce() async throws {
        let harness = try AudioHarness()
        try await harness.player.prepare(current: harness.files.a, next: nil)
        _ = try await harness.player.play()
        let engine = try XCTUnwrap(harness.factory.engine(for: harness.files.a))
        let finish = engine.queuedFinish()
        let failure = engine.queuedDecodeFailure()

        await finish()
        let settled = await harness.player.snapshot()
        await finish()
        await failure()

        XCTAssertEqual(settled.phase, .finished)
        let afterLateCallbacks = await harness.player.snapshot()
        XCTAssertEqual(afterLateCallbacks, settled)
        XCTAssertEqual(harness.session.calls.filter { $0 == .deactivate }.count, 1)
    }

    func testDecodeStartAndSessionFailuresAreTypedAndDeactivate() async throws {
        do {
            let harness = try AudioHarness()
            try await harness.player.prepare(current: harness.files.a, next: nil)
            let requestID = try await harness.player.play()
            let engine = try XCTUnwrap(harness.factory.engine(for: harness.files.a))
            await engine.fireDecodeFailure()
            let snapshot = await harness.player.snapshot()
            XCTAssertEqual(snapshot.phase, .failed)
            XCTAssertEqual(snapshot.error, .decodeFailed)
            XCTAssertEqual(snapshot.requestID, requestID)
        }

        do {
            let harness = try AudioHarness()
            try await harness.player.prepare(current: harness.files.a, next: nil)
            let engine = try XCTUnwrap(harness.factory.engine(for: harness.files.a))
            engine.playResult = false
            await assertThrows(.playbackStartFailed) { _ = try await harness.player.play() }
            let snapshot = await harness.player.snapshot()
            XCTAssertEqual(snapshot.error, .playbackStartFailed)
            XCTAssertEqual(harness.session.calls, [.configure, .activate, .deactivate])
        }


        do {
            let harness = try AudioHarness()
            try await harness.player.prepare(current: harness.files.a, next: nil)
            harness.session.configurationFails = true
            await assertThrows(.sessionActivationFailed) { _ = try await harness.player.play() }
            XCTAssertEqual(harness.factory.engine(for: harness.files.a)?.playCount, 0)
            XCTAssertEqual(harness.session.calls, [.configure, .deactivate])
        }

        do {
            let harness = try AudioHarness()
            try await harness.player.prepare(current: harness.files.a, next: nil)
            harness.session.activationFails = true
            await assertThrows(.sessionActivationFailed) { _ = try await harness.player.play() }
            XCTAssertEqual(harness.factory.engine(for: harness.files.a)?.playCount, 0)
            XCTAssertEqual(harness.session.calls, [.configure, .activate, .deactivate])
        }
    }

    func testUserPausePreservesPositionAndResumeUsesNewToken() async throws {
        let harness = try AudioHarness()
        try await harness.player.prepare(current: harness.files.a, next: harness.files.b)
        let first = try await harness.player.play()
        let engine = try XCTUnwrap(harness.factory.engine(for: harness.files.a))
        engine.currentTime = 2.75
        let lateFinish = engine.queuedFinish()

        await harness.player.pause()
        await lateFinish()
        let paused = await harness.player.snapshot()
        XCTAssertEqual(paused.phase, .paused)
        XCTAssertEqual(paused.pauseReason, .user)
        XCTAssertEqual(paused.requestID, first)
        XCTAssertEqual(engine.currentTime, 2.75)

        let second = try await harness.player.play()
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(engine.currentTime, 2.75)
        let resumed = await harness.player.snapshot()
        XCTAssertEqual(resumed.phase, .playing)
    }

    func testStopInvalidatesLateCallbacksAndReleasesBothSlots() async throws {
        let harness = try AudioHarness()
        try await harness.player.prepare(current: harness.files.a, next: harness.files.b)
        _ = try await harness.player.play()
        let engine = try XCTUnwrap(harness.factory.engine(for: harness.files.a))
        let lateFailure = engine.queuedDecodeFailure()

        await harness.player.stop()
        await lateFailure()

        let stopped = await harness.player.snapshot()
        XCTAssertEqual(
            stopped,
            AudioPlaybackSnapshot(
                phase: .stopped,
                currentURL: nil,
                nextURL: nil,
                requestID: nil,
                pauseReason: nil,
                error: nil
            )
        )
        XCTAssertTrue(harness.factory.engines.allSatisfy(\.isStopped))
        await assertThrows(.invalidState) { _ = try await harness.player.play() }
    }

    func testRapidABCReplacementIgnoresAllOldCallbacks() async throws {
        let harness = try AudioHarness()
        try await harness.player.prepare(current: harness.files.a, next: nil)
        _ = try await harness.player.play()
        let a = try XCTUnwrap(harness.factory.engine(for: harness.files.a))
        let aFinish = a.queuedFinish()

        try await harness.player.prepare(current: harness.files.b, next: nil)
        _ = try await harness.player.play()
        let b = try XCTUnwrap(harness.factory.engine(for: harness.files.b))
        let bFailure = b.queuedDecodeFailure()

        try await harness.player.prepare(current: harness.files.c, next: nil)
        let cToken = try await harness.player.play()
        await aFinish()
        await bFailure()

        let snapshot = await harness.player.snapshot()
        XCTAssertEqual(snapshot.phase, .playing)
        XCTAssertEqual(snapshot.currentURL, harness.files.c.standardizedFileURL)
        XCTAssertEqual(snapshot.requestID, cToken)
    }

    func testInterruptionRouteAndBackgroundPauseWithoutAutoResume() async throws {
        for (event, reason) in [
            (AudioSystemEvent.interruptionBegan, AudioPauseReason.interruption),
            (.oldDeviceUnavailable, .oldDeviceUnavailable),
            (.lifecycleBackground, .background),
        ] {
            let harness = try AudioHarness()
            try await harness.player.prepare(current: harness.files.a, next: harness.files.b)
            let token = try await harness.player.play()
            let engine = try XCTUnwrap(harness.factory.engine(for: harness.files.a))
            let lateFinish = engine.queuedFinish()

            await harness.systemEvents.send(event)
            await lateFinish()
            await harness.systemEvents.send(.interruptionEnded)
            await harness.systemEvents.send(.lifecycleActive)

            let snapshot = await harness.player.snapshot()
            XCTAssertEqual(snapshot.phase, .paused)
            XCTAssertEqual(snapshot.pauseReason, reason)
            XCTAssertEqual(snapshot.requestID, token)
            XCTAssertEqual(engine.playCount, 1)
        }
    }

    func testUnrelatedRouteAndLifecycleEventsDoNotChangePlayback() async throws {
        let harness = try AudioHarness()
        try await harness.player.prepare(current: harness.files.a, next: nil)
        let token = try await harness.player.play()

        await harness.systemEvents.send(.otherRouteChange)
        await harness.systemEvents.send(.lifecycleInactive)
        await harness.systemEvents.send(.lifecycleActive)
        await harness.systemEvents.send(.interruptionEnded)

        let snapshot = await harness.player.snapshot()
        XCTAssertEqual(snapshot.phase, .playing)
        XCTAssertEqual(snapshot.requestID, token)
    }

    func testMediaServicesResetFailsClosedAndRequiresPrepare() async throws {
        let harness = try AudioHarness()
        try await harness.player.prepare(current: harness.files.a, next: harness.files.b)
        let token = try await harness.player.play()

        await harness.systemEvents.send(.mediaServicesReset)

        let snapshot = await harness.player.snapshot()
        XCTAssertEqual(snapshot.phase, .failed)
        XCTAssertEqual(snapshot.error, .mediaServicesReset)
        XCTAssertEqual(snapshot.requestID, token)
        XCTAssertNil(snapshot.currentURL)
        XCTAssertNil(snapshot.nextURL)
        await assertThrows(.invalidState) { _ = try await harness.player.play() }
    }

    func testSessionOrderingIsConfigureActivatePlayAndTerminalStatesDeactivate() async throws {
        let log = LockedCallLog()
        let harness = try AudioHarness(log: log)
        try await harness.player.prepare(current: harness.files.a, next: nil)
        XCTAssertTrue(log.values.isEmpty)

        _ = try await harness.player.play()
        XCTAssertEqual(log.values, ["session.configure", "session.activate", "engine.play"])
        await harness.factory.engine(for: harness.files.a)?.fireFinish()
        XCTAssertEqual(log.values.last, "session.deactivate")
    }

    func testEventsBroadcastInTheSameOrderAndCancelledSubscriberIsRemoved() async throws {
        let harness = try AudioHarness()
        let stream1 = await harness.player.events()
        let stream2 = await harness.player.events()
        let recorder1 = EventRecorder(stream: stream1)
        let recorder2 = EventRecorder(stream: stream2)
        let initialSubscriberCount = await harness.player.subscriberCount()
        XCTAssertEqual(initialSubscriberCount, 2)

        try await harness.player.prepare(current: harness.files.a, next: harness.files.b)
        _ = try await harness.player.play()
        await harness.player.pause()

        let first = await recorder1.waitForCount(3)
        let second = await recorder2.waitForCount(3)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.compactMap(\.snapshotPhase), [.prepared, .playing, .paused])

        recorder2.cancel()
        await waitUntil { await harness.player.subscriberCount() == 1 }
        let remainingSubscriberCount = await harness.player.subscriberCount()
        XCTAssertEqual(remainingSubscriberCount, 1)
        recorder1.cancel()
    }

    private func assertPrepareError(_ expected: AudioPlayerError, url: URL, player: AudioPlayer) async {
        await assertThrows(expected) {
            try await player.prepare(current: url, next: nil)
        }
        let snapshot = await player.snapshot()
        XCTAssertEqual(snapshot.phase, .failed)
        XCTAssertEqual(snapshot.error, expected)
        XCTAssertNil(snapshot.currentURL)
    }

    private func assertThrows(
        _ expected: AudioPlayerError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)")
        } catch let error as AudioPlayerError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func waitUntil(
        attempts: Int = 200,
        _ predicate: () async -> Bool
    ) async {
        for _ in 0..<attempts {
            if await predicate() { return }
            await Task.yield()
        }
        XCTFail("Condition did not become true")
    }
}

private extension AudioPlayerEvent {
    var snapshotPhase: AudioPlaybackPhase? {
        guard case let .stateChanged(snapshot) = self else { return nil }
        return snapshot.phase
    }
}

private final class AudioHarness {
    let files: TemporaryAudioFiles
    let factory: FakeAudioEngineFactory
    let session: FakeAudioSession
    let systemEvents: FakeAudioSystemEventSource
    let player: AudioPlayer

    init(log: LockedCallLog = .init()) throws {
        files = try TemporaryAudioFiles()
        factory = FakeAudioEngineFactory(log: log)
        session = FakeAudioSession(log: log)
        systemEvents = FakeAudioSystemEventSource()
        player = AudioPlayer(
            engineFactory: factory,
            session: session,
            systemEventSource: systemEvents
        )
    }
}

private final class TemporaryAudioFiles {
    let directory: URL
    let a: URL
    let b: URL
    let c: URL
    let missing: URL
    let symlink: URL
    let fifo: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WordLoopAudioTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        a = directory.appendingPathComponent("a.m4a")
        b = directory.appendingPathComponent("b.m4a")
        c = directory.appendingPathComponent("c.m4a")
        missing = directory.appendingPathComponent("missing.m4a")
        symlink = directory.appendingPathComponent("symlink.m4a")
        fifo = directory.appendingPathComponent("fifo.m4a")
        try Data([0x00, 0x01]).write(to: a)
        try Data([0x02, 0x03]).write(to: b)
        try Data([0x04, 0x05]).write(to: c)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: a)
        guard mkfifo(fifo.path, S_IRUSR | S_IWUSR) == 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }
}

private final class FakeAudioEngine: AudioEngine {
    let id = UUID()
    let url: URL
    let log: LockedCallLog
    var currentTime: TimeInterval = 0
    var prepareResult = true
    var playResult = true
    var prepareCount = 0
    var playCount = 0
    var pauseCount = 0
    var stopCount = 0
    var clearCallbacksCount = 0
    var isStopped = false
    private var onFinish: (@Sendable () async -> Void)?
    private var onDecodeFailure: (@Sendable () async -> Void)?

    init(url: URL, log: LockedCallLog) {
        self.url = url
        self.log = log
    }

    func prepareToPlay() -> Bool {
        prepareCount += 1
        return prepareResult
    }

    func play() -> Bool {
        playCount += 1
        isStopped = false
        log.append("engine.play")
        return playResult
    }

    func pause() { pauseCount += 1 }
    func stop() {
        stopCount += 1
        isStopped = true
    }

    func installCallbacks(
        onFinish: @escaping @Sendable () async -> Void,
        onDecodeFailure: @escaping @Sendable () async -> Void
    ) {
        self.onFinish = onFinish
        self.onDecodeFailure = onDecodeFailure
    }

    func clearCallbacks() {
        clearCallbacksCount += 1
        onFinish = nil
        onDecodeFailure = nil
    }

    func queuedFinish() -> @Sendable () async -> Void {
        onFinish ?? {}
    }

    func queuedDecodeFailure() -> @Sendable () async -> Void {
        onDecodeFailure ?? {}
    }

    func fireFinish() async { await onFinish?() }
    func fireDecodeFailure() async { await onDecodeFailure?() }
}

private final class FakeAudioEngineFactory: AudioEngineFactory, @unchecked Sendable {
    let log: LockedCallLog
    var engines: [FakeAudioEngine] = []
    var prepareFailures: Set<URL> = []
    var creationFailures: Set<URL> = []

    init(log: LockedCallLog) {
        self.log = log
    }

    func makeEngine(url: URL) throws -> any AudioEngine {
        if creationFailures.contains(url) { throw CocoaError(.fileReadCorruptFile) }
        let engine = FakeAudioEngine(url: url, log: log)
        engine.prepareResult = !prepareFailures.contains(url)
        engines.append(engine)
        return engine
    }

    func engine(for url: URL) -> FakeAudioEngine? {
        engines.last { $0.url == url.standardizedFileURL }
    }
}

private enum SessionCall: Equatable {
    case configure
    case activate
    case deactivate
}

private final class FakeAudioSession: AudioSessionControlling, @unchecked Sendable {
    let log: LockedCallLog
    var calls: [SessionCall] = []
    var configurationFails = false
    var activationFails = false

    init(log: LockedCallLog) {
        self.log = log
    }

    func configureForSpokenPlayback() throws {
        calls.append(.configure)
        log.append("session.configure")
        if configurationFails { throw CocoaError(.featureUnsupported) }
    }

    func activate() throws {
        calls.append(.activate)
        log.append("session.activate")
        if activationFails { throw CocoaError(.featureUnsupported) }
    }

    func deactivate() {
        calls.append(.deactivate)
        log.append("session.deactivate")
    }
}

private final class FakeAudioSystemEventSource: AudioSystemEventSource, @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable (AudioSystemEvent) async -> Void)?

    func setHandler(_ handler: (@Sendable (AudioSystemEvent) async -> Void)?) {
        lock.withLock { self.handler = handler }
    }

    func send(_ event: AudioSystemEvent) async {
        let callback: (@Sendable (AudioSystemEvent) async -> Void)? = lock.withLock { self.handler }
        await callback?(event)
    }
}

private final class LockedCallLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var values: [String] { lock.withLock { storage } }

    func append(_ value: String) {
        lock.withLock { storage.append(value) }
    }
}

private final class EventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [AudioPlayerEvent] = []
    private var consumer: Task<Void, Never>?

    init(stream: AsyncStream<AudioPlayerEvent>) {
        consumer = Task { [weak self] in
            for await event in stream {
                self?.append(event)
            }
        }
    }

    func waitForCount(_ count: Int, attempts: Int = 200) async -> [AudioPlayerEvent] {
        for _ in 0..<attempts {
            let snapshot = lock.withLock { events }
            if snapshot.count >= count { return snapshot }
            await Task.yield()
        }
        return lock.withLock { events }
    }

    func cancel() {
        let task = lock.withLock { () -> Task<Void, Never>? in
            defer { consumer = nil }
            return consumer
        }
        task?.cancel()
    }

    private func append(_ event: AudioPlayerEvent) {
        lock.withLock { events.append(event) }
    }
}
