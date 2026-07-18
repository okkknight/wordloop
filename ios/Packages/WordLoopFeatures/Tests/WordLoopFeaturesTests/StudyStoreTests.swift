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

    func testStartRestoresAvailablePreferredCourseAndFallsBackForUnknownCourse() async {
        let preferred = makeHarness()
        await preferred.store.start(preferredCourseID: preferred.secondary.id)
        XCTAssertEqual(preferred.store.state.selectedCourseID, preferred.secondary.id)

        let fallback = makeHarness()
        await fallback.store.start(preferredCourseID: CourseID(rawValue: "unknown-course"))
        XCTAssertEqual(fallback.store.state.selectedCourseID, fallback.primary.id)
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

    func testOldNextSuspendedOnProgressCannotOverrideNewerCourseSelection() async {
        let harness = makeHarness()
        await enterListen(harness)
        await harness.progress.suspendNextSnapshot()

        let oldNext = Task { @MainActor in await harness.store.next() }
        await harness.progress.waitUntilSnapshotIsSuspended()
        await harness.store.selectCourse(harness.secondary.id.rawValue)
        let selectedToken = try! XCTUnwrap(harness.store.state.activePlaybackRequestID)
        await harness.progress.releaseSuspendedSnapshot()
        await oldNext.value

        XCTAssertEqual(harness.store.state.selectedCourseID, harness.secondary.id)
        XCTAssertEqual(harness.store.state.currentEntryID, harness.secondary.entries[0].id)
        XCTAssertEqual(harness.store.state.activePlaybackRequestID, selectedToken)
        XCTAssertEqual(harness.store.state.listenPhase, .playing)
    }

    func testOldTooEasySuspendedOnMasterCannotAdvanceNewerCourse() async {
        let harness = makeHarness()
        await enterListen(harness)
        await harness.progress.suspendNextMaster()

        let oldTooEasy = Task { @MainActor in await harness.store.markTooEasy() }
        await harness.progress.waitUntilMasterIsSuspended()
        await harness.store.selectCourse(harness.secondary.id.rawValue)
        let selectedToken = try! XCTUnwrap(harness.store.state.activePlaybackRequestID)
        await harness.progress.releaseSuspendedMaster()
        await oldTooEasy.value

        XCTAssertEqual(harness.store.state.selectedCourseID, harness.secondary.id)
        XCTAssertEqual(harness.store.state.currentEntryID, harness.secondary.entries[0].id)
        XCTAssertEqual(harness.store.state.activePlaybackRequestID, selectedToken)
        assertEqual(
            await harness.progress.counts(courseID: harness.secondary.id, mode: .listen),
            [harness.secondary.entries[0].id: 1]
        )
    }

    func testConcurrentNextIntentsCollapseToOneNewLearningRound() async {
        let harness = makeHarness()
        await enterListen(harness)
        await harness.audio.suspendNextStops(count: 3)

        let tasks = (0..<3).map { _ in
            Task { @MainActor in await harness.store.next() }
        }
        await harness.audio.waitUntilStopsAreSuspended()
        await harness.audio.releaseSuspendedStops()
        for task in tasks { await task.value }

        XCTAssertEqual(harness.store.state.currentEntryID, harness.primary.entries[1].id)
        XCTAssertEqual(harness.store.state.listenPhase, .playing)
        assertEqual(await harness.audio.playCallCount(), 2)
        assertEqual(
            await harness.progress.counts(courseID: harness.primary.id, mode: .listen),
            [harness.primary.entries[0].id: 1, harness.primary.entries[1].id: 1]
        )
    }

    func testOldCourseLoadCannotOverrideNewerABCSelection() async {
        let harness = makeHarness()
        await enterListen(harness)
        await harness.courses.suspendNextLoad(of: harness.secondary.id)

        let oldSelection = Task { @MainActor in
            await harness.store.selectCourse(harness.secondary.id.rawValue)
        }
        await harness.courses.waitUntilLoadIsSuspended()
        await harness.store.selectCourse(harness.tertiary.id.rawValue)
        let tertiaryToken = try! XCTUnwrap(harness.store.state.activePlaybackRequestID)
        await harness.courses.releaseSuspendedLoad()
        await oldSelection.value

        XCTAssertEqual(harness.store.state.selectedCourseID, harness.tertiary.id)
        XCTAssertEqual(harness.store.state.currentEntryID, harness.tertiary.entries[0].id)
        XCTAssertEqual(harness.store.state.activePlaybackRequestID, tertiaryToken)
    }

    func testNilRequestTerminalEventsAndPreloadFailureCannotPoisonCurrentPlayback() async {
        let harness = makeHarness()
        await enterListen(harness)
        let token = try! XCTUnwrap(harness.store.state.activePlaybackRequestID)

        for phase in [AudioPlaybackPhase.finished, .paused, .failed] {
            harness.audio.emit(.stateChanged(snapshot(
                phase: phase,
                currentURL: harness.primary.entries[0].audioURL,
                requestID: nil,
                error: phase == .failed ? .mediaServicesReset : nil
            )))
        }
        harness.audio.emit(.preloadFailed(harness.primary.entries[1].audioURL, .couldNotPrepare))
        for _ in 0..<30 { await Task.yield() }

        XCTAssertEqual(harness.store.state.listenPhase, .playing)
        XCTAssertEqual(harness.store.state.activePlaybackRequestID, token)
        XCTAssertEqual(harness.store.state.currentEntryID, harness.primary.entries[0].id)
    }

    func testCourseLoadFailureCanRetryTheRequestedCourse() async {
        let harness = makeHarness()
        await enterListen(harness)
        await harness.courses.failNextLoad(of: harness.secondary.id)

        await harness.store.selectCourse(harness.secondary.id.rawValue)
        XCTAssertEqual(harness.store.state.phase, .failed)
        XCTAssertEqual(harness.store.state.listenPhase, .failed)

        await harness.store.retry()

        XCTAssertEqual(harness.store.state.phase, .ready)
        XCTAssertEqual(harness.store.state.selectedCourseID, harness.secondary.id)
        XCTAssertEqual(harness.store.state.currentEntryID, harness.secondary.entries[0].id)
        XCTAssertEqual(harness.store.state.listenPhase, .playing)
    }

    func testPrepareAndPlayFailuresRemainRetryableWithoutExtraReplayProgress() async {
        let prepareHarness = makeHarness()
        await prepareHarness.store.start()
        await prepareHarness.audio.failNextPrepare()
        await prepareHarness.store.selectMode(.listen)
        XCTAssertEqual(prepareHarness.store.state.listenPhase, .failed)
        await prepareHarness.store.playCurrent()
        XCTAssertEqual(prepareHarness.store.state.listenPhase, .playing)
        assertEqual(
            await prepareHarness.progress.counts(courseID: prepareHarness.primary.id, mode: .listen),
            [prepareHarness.primary.entries[0].id: 1]
        )

        let playHarness = makeHarness()
        await playHarness.store.start()
        await playHarness.audio.failNextPlay()
        await playHarness.store.selectMode(.listen)
        XCTAssertEqual(playHarness.store.state.listenPhase, .failed)
        await playHarness.store.playCurrent()
        XCTAssertEqual(playHarness.store.state.listenPhase, .playing)
        assertEqual(
            await playHarness.progress.counts(courseID: playHarness.primary.id, mode: .listen),
            [playHarness.primary.entries[0].id: 1]
        )
    }

    func testManualNextAndRepeatDuringWaitingCancelOldClockWake() async {
        let nextHarness = makeHarness()
        await enterListen(nextHarness)
        await nextHarness.store.toggleAutoplay()
        let nextToken = try! XCTUnwrap(nextHarness.store.state.activePlaybackRequestID)
        nextHarness.audio.emit(.stateChanged(snapshot(
            phase: .finished,
            currentURL: nextHarness.primary.entries[0].audioURL,
            requestID: nextToken
        )))
        await eventually { nextHarness.store.state.listenPhase == .waiting }
        await nextHarness.store.next()
        XCTAssertEqual(nextHarness.store.state.currentEntryID, nextHarness.primary.entries[1].id)
        await nextHarness.clock.advanceAll()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(nextHarness.store.state.currentEntryID, nextHarness.primary.entries[1].id)

        let repeatHarness = makeHarness()
        await enterListen(repeatHarness)
        await repeatHarness.store.toggleAutoplay()
        let repeatToken = try! XCTUnwrap(repeatHarness.store.state.activePlaybackRequestID)
        repeatHarness.audio.emit(.stateChanged(snapshot(
            phase: .finished,
            currentURL: repeatHarness.primary.entries[0].audioURL,
            requestID: repeatToken
        )))
        await eventually { repeatHarness.store.state.listenPhase == .waiting }
        await repeatHarness.store.selectMode(.repeat)
        await repeatHarness.clock.advanceAll()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(repeatHarness.store.shellStore.state.mode, .repeat)
        XCTAssertEqual(repeatHarness.store.state.currentEntryID, repeatHarness.primary.entries[0].id)
        XCTAssertEqual(repeatHarness.store.state.listenPhase, .idle)
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
        XCTAssertTrue(harness.store.completionDialogStore.state.isPresented)
        XCTAssertEqual(harness.store.completionDialogStore.state.kind, .courseCompleted)
        assertEqual(await harness.progress.completions(), [harness.primary.id: 1])
        let completedCard = harness.store.courseDrawerStore.state.collections
            .flatMap(\.courses)
            .first { $0.id == harness.primary.id.rawValue }
        XCTAssertEqual(completedCard?.completionCount, 1)

        let playCountAtMastery = await harness.audio.playCallCount()
        await harness.store.next()
        XCTAssertTrue(harness.store.state.courseExhausted)
        assertEqual(await harness.audio.playCallCount(), playCountAtMastery)
        assertEqual(await harness.progress.counts(courseID: harness.primary.id, mode: .listen), [onlyID: 3])
        assertEqual(await harness.progress.completions(), [harness.primary.id: 1])
    }

    func testNaturalCompletionCanRestartWithoutLosingCompletionCount() async {
        let harness = makeHarness(primaryEntryCount: 1)
        await enterListen(harness)
        await harness.store.next()
        await harness.store.next()

        await harness.store.restartCourse(harness.primary.id.rawValue)

        XCTAssertFalse(harness.store.completionDialogStore.state.isPresented)
        XCTAssertEqual(harness.store.state.selectedCourseID, harness.primary.id)
        XCTAssertEqual(harness.store.state.listenPhase, .playing)
        assertEqual(
            await harness.progress.counts(courseID: harness.primary.id, mode: .listen),
            [harness.primary.entries[0].id: 1]
        )
        assertEqual(await harness.progress.completions(), [harness.primary.id: 1])
    }

    func testSelectingCompletedCoursePromptsBeforeResetAndThenStartsIt() async {
        let harness = makeHarness()
        await enterListen(harness)
        await harness.progress.seedMastered(
            courseID: harness.secondary.id,
            mode: .listen,
            entries: harness.secondary.entries.map(\.id)
        )

        await harness.store.selectCourse(harness.secondary.id.rawValue)

        XCTAssertEqual(harness.store.state.selectedCourseID, harness.primary.id)
        XCTAssertTrue(harness.store.completionDialogStore.state.isPresented)
        XCTAssertEqual(harness.store.completionDialogStore.state.kind, .restartCompletedCourse)
        XCTAssertEqual(harness.store.completionDialogStore.state.courseID, harness.secondary.id.rawValue)

        await harness.store.restartCourse(harness.secondary.id.rawValue)

        XCTAssertEqual(harness.store.state.selectedCourseID, harness.secondary.id)
        XCTAssertFalse(harness.store.completionDialogStore.state.isPresented)
        assertEqual(
            await harness.progress.counts(courseID: harness.secondary.id, mode: .listen),
            [harness.secondary.entries[0].id: 1]
        )
    }

    func testResetFailureKeepsDialogOpenWithFixedRetryableError() async {
        let harness = makeHarness(primaryEntryCount: 1)
        await enterListen(harness)
        await harness.store.next()
        await harness.store.next()
        await harness.progress.failNextReset()

        await harness.store.restartCourse(harness.primary.id.rawValue)

        XCTAssertTrue(harness.store.completionDialogStore.state.isPresented)
        XCTAssertEqual(
            harness.store.completionDialogStore.state.errorMessage,
            CompletionDialogViewState.fixedErrorMessage
        )
        await harness.store.restartCourse(harness.primary.id.rawValue)
        XCTAssertFalse(harness.store.completionDialogStore.state.isPresented)
        XCTAssertEqual(harness.store.state.listenPhase, .playing)
    }

    func testSuspendedResetCannotOverwriteNewerCourseSelection() async {
        let harness = makeHarness(primaryEntryCount: 1)
        await enterListen(harness)
        await harness.store.next()
        await harness.store.next()
        await harness.progress.suspendNextReset()

        let oldReset = Task { @MainActor in
            await harness.store.restartCourse(harness.primary.id.rawValue)
        }
        await harness.progress.waitUntilResetIsSuspended()
        await harness.store.selectCourse(harness.secondary.id.rawValue)
        let selectedToken = try! XCTUnwrap(harness.store.state.activePlaybackRequestID)
        await harness.progress.releaseSuspendedReset()
        await oldReset.value

        XCTAssertEqual(harness.store.state.selectedCourseID, harness.secondary.id)
        XCTAssertEqual(harness.store.state.currentEntryID, harness.secondary.entries[0].id)
        XCTAssertEqual(harness.store.state.activePlaybackRequestID, selectedToken)
        XCTAssertEqual(harness.store.state.listenPhase, .playing)
        XCTAssertTrue(harness.store.completionDialogStore.state.isPresented)
        XCTAssertEqual(harness.store.completionDialogStore.state.kind, .courseCompleted)
    }

    func testSuspendedResetCannotOverwriteNewerModeIntent() async {
        let harness = makeHarness(primaryEntryCount: 1)
        await enterListen(harness)
        await harness.store.next()
        await harness.store.next()
        await harness.progress.suspendNextReset()

        let oldReset = Task { @MainActor in
            await harness.store.restartCourse(harness.primary.id.rawValue)
        }
        await harness.progress.waitUntilResetIsSuspended()
        await harness.store.selectMode(.repeat)
        await harness.progress.releaseSuspendedReset()
        await oldReset.value

        XCTAssertEqual(harness.store.shellStore.state.mode, .repeat)
        XCTAssertEqual(harness.store.state.listenPhase, .idle)
        XCTAssertNil(harness.store.state.activePlaybackRequestID)
        XCTAssertTrue(harness.store.completionDialogStore.state.isPresented)
        XCTAssertEqual(harness.store.completionDialogStore.state.kind, .courseCompleted)
    }

    func testSuspendedCompletionCannotPresentOverNewerCourseSession() async {
        let harness = makeHarness(primaryEntryCount: 1)
        await enterListen(harness)
        await harness.store.next()
        await harness.progress.suspendNextComplete()

        let oldCompletion = Task { @MainActor in await harness.store.next() }
        await harness.progress.waitUntilCompleteIsSuspended()
        await harness.store.selectCourse(harness.secondary.id.rawValue)
        let selectedToken = try! XCTUnwrap(harness.store.state.activePlaybackRequestID)
        await harness.progress.releaseSuspendedComplete()
        await oldCompletion.value

        XCTAssertEqual(harness.store.state.selectedCourseID, harness.secondary.id)
        XCTAssertEqual(harness.store.state.currentEntryID, harness.secondary.entries[0].id)
        XCTAssertEqual(harness.store.state.activePlaybackRequestID, selectedToken)
        XCTAssertEqual(harness.store.state.listenPhase, .playing)
        XCTAssertFalse(harness.store.completionDialogStore.state.isPresented)
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

    func testOlderSuspendedModeIntentCannotOverwriteNewerModeIntent() async {
        let harness = makeHarness()
        await harness.store.start()
        await harness.audio.suspendNextStops(count: 1)

        let oldListen = Task { @MainActor in await harness.store.selectMode(.listen) }
        await harness.audio.waitUntilStopsAreSuspended()
        await harness.store.selectMode(.repeat)
        await harness.audio.releaseSuspendedStops()
        await oldListen.value

        XCTAssertEqual(harness.store.shellStore.state.mode, .repeat)
        XCTAssertEqual(harness.store.state.listenPhase, .idle)
        XCTAssertNil(harness.store.state.activePlaybackRequestID)
        assertEqual(await harness.audio.playCallCount(), 0)
        assertEqual(await harness.progress.counts(courseID: harness.primary.id, mode: .listen), [:])
    }

    func testOlderSuspendedBackgroundPauseCannotOverwriteNewerSession() async {
        let harness = makeHarness()
        await enterListen(harness)
        await harness.audio.suspendNextPauses(count: 1)

        let oldBackground = Task { @MainActor in
            await harness.store.setApplicationActive(false)
        }
        await harness.audio.waitUntilPausesAreSuspended()
        await harness.store.next()
        let currentToken = try! XCTUnwrap(harness.store.state.activePlaybackRequestID)
        await harness.audio.releaseSuspendedPauses()
        await oldBackground.value

        XCTAssertEqual(harness.store.state.currentEntryID, harness.primary.entries[1].id)
        XCTAssertEqual(harness.store.state.activePlaybackRequestID, currentToken)
        XCTAssertEqual(harness.store.state.listenPhase, .playing)
    }

    func testBackgroundDuringCourseLoadingLeavesRetryableFailure() async {
        let harness = makeHarness()
        await harness.store.start()
        await harness.courses.suspendNextLoad(of: harness.secondary.id)

        let selection = Task { @MainActor in
            await harness.store.selectCourse(harness.secondary.id.rawValue)
        }
        await harness.courses.waitUntilLoadIsSuspended()
        XCTAssertEqual(harness.store.state.phase, .loading)
        await harness.store.setApplicationActive(false)
        await harness.courses.releaseSuspendedLoad()
        await selection.value

        XCTAssertEqual(harness.store.state.phase, .failed)
        XCTAssertEqual(harness.store.state.listenPhase, .failed)
        await harness.store.retry()
        XCTAssertEqual(harness.store.state.phase, .ready)
        XCTAssertEqual(harness.store.state.selectedCourseID, harness.secondary.id)
    }

    func testModeIntentIsRejectedWhileInitialCourseIsLoading() async {
        let harness = makeHarness()
        await harness.courses.suspendNextLoad(of: harness.primary.id)

        let start = Task { @MainActor in await harness.store.start() }
        await harness.courses.waitUntilLoadIsSuspended()
        await harness.store.selectMode(.listen)

        XCTAssertEqual(harness.store.state.phase, .loading)
        XCTAssertEqual(harness.store.shellStore.state.mode, .repeat)
        await harness.courses.releaseSuspendedLoad()
        await start.value
        XCTAssertEqual(harness.store.state.phase, .ready)
        XCTAssertEqual(harness.store.shellStore.state.mode, .repeat)
        assertEqual(await harness.audio.playCallCount(), 0)
    }

    private func enterListen(_ harness: StudyHarness) async {
        await harness.store.start()
        await harness.store.selectMode(.listen)
        XCTAssertEqual(harness.store.state.listenPhase, .playing)
    }

    private func makeHarness(primaryEntryCount: Int = 3) -> StudyHarness {
        let primary = makeCourse(id: "course-one", entryCount: primaryEntryCount)
        let secondary = makeCourse(id: "course-two", entryCount: 3)
        let tertiary = makeCourse(id: "course-three", entryCount: 3)
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
            courses: [primary.descriptor, secondary.descriptor, tertiary.descriptor]
        )
        let audio = TestAudio()
        let progress = TestProgress()
        let clock = TestClock()
        let courses = TestCourses(catalog: catalog, courses: [primary, secondary, tertiary])
        let store = StudyStore(
            courses: courses.client,
            audio: audio.client,
            progress: progress.client,
            clock: clock.client,
            random: StudyRandomClient(index: { _ in 0 })
        )
        return StudyHarness(
            store: store,
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            courses: courses,
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
    let tertiary: Course
    let courses: TestCourses
    let audio: TestAudio
    let progress: TestProgress
    let clock: TestClock
}

private enum TestError: Error {
    case missingCourse
    case forcedFailure
}

private actor TestCourses {
    private let catalogValue: CourseCatalog
    private let coursesByID: [CourseID: Course]
    private let loadSuspension = OneShotSuspension()
    private var suspendedCourseID: CourseID?
    private var failingCourseIDs: Set<CourseID> = []

    init(catalog: CourseCatalog, courses: [Course]) {
        catalogValue = catalog
        coursesByID = Dictionary(uniqueKeysWithValues: courses.map { ($0.id, $0) })
    }

    nonisolated var client: StudyCourseClient {
        StudyCourseClient(
            catalog: { [weak self] in
                guard let self else { throw TestError.missingCourse }
                return self.catalogValue
            },
            course: { [weak self] id in
                guard let self else { throw TestError.missingCourse }
                return try await self.load(id)
            }
        )
    }

    func suspendNextLoad(of courseID: CourseID) async {
        suspendedCourseID = courseID
        await loadSuspension.arm()
    }

    func waitUntilLoadIsSuspended() async {
        await loadSuspension.waitUntilSuspended()
    }

    func releaseSuspendedLoad() async {
        await loadSuspension.release()
    }

    func failNextLoad(of courseID: CourseID) {
        failingCourseIDs.insert(courseID)
    }

    private func load(_ id: CourseID) async throws -> Course {
        if suspendedCourseID == id {
            suspendedCourseID = nil
            await loadSuspension.suspendIfArmed()
        }
        if failingCourseIDs.remove(id) != nil {
            throw TestError.forcedFailure
        }
        guard let course = coursesByID[id] else { throw TestError.missingCourse }
        return course
    }
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
            prepare: { [recorder] current, next in try await recorder.prepare(current, next) },
            play: { [recorder] in try await recorder.play() },
            pause: { [recorder] in await recorder.pause() },
            stop: { [recorder] in await recorder.stop() },
            snapshot: { [recorder] in await recorder.snapshot() },
            events: { [stream] in stream },
            configureForRepeat: {}
        )
    }

    func emit(_ event: AudioPlayerEvent) {
        continuation.yield(event)
    }

    func prepareCalls() async -> [PrepareCall] { await recorder.prepareCalls }
    func playCallCount() async -> Int { await recorder.playCallCount }
    func pauseCallCount() async -> Int { await recorder.pauseCallCount }
    func stopCallCount() async -> Int { await recorder.stopCallCount }
    func failNextPrepare() async { await recorder.failNextPrepare() }
    func failNextPlay() async { await recorder.failNextPlay() }
    func suspendNextStops(count: Int) async { await recorder.suspendNextStops(count: count) }
    func waitUntilStopsAreSuspended() async { await recorder.waitUntilStopsAreSuspended() }
    func releaseSuspendedStops() async { await recorder.releaseSuspendedStops() }
    func suspendNextPauses(count: Int) async { await recorder.suspendNextPauses(count: count) }
    func waitUntilPausesAreSuspended() async { await recorder.waitUntilPausesAreSuspended() }
    func releaseSuspendedPauses() async { await recorder.releaseSuspendedPauses() }
}

private actor TestAudioRecorder {
    private(set) var prepareCalls: [PrepareCall] = []
    private(set) var playCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var stopCallCount = 0
    private let stopBarrier = CountedSuspension()
    private let pauseBarrier = CountedSuspension()
    private var shouldFailNextPrepare = false
    private var shouldFailNextPlay = false
    private var latestSnapshot = AudioPlaybackSnapshot(
        phase: .idle,
        currentURL: nil,
        nextURL: nil,
        requestID: nil,
        pauseReason: nil,
        error: nil
    )

    func prepare(_ current: URL, _ next: URL?) throws {
        if shouldFailNextPrepare {
            shouldFailNextPrepare = false
            throw AudioPlayerError.couldNotPrepare
        }
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

    func play() throws -> PlaybackRequestID {
        if shouldFailNextPlay {
            shouldFailNextPlay = false
            throw AudioPlayerError.playbackStartFailed
        }
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

    func pause() async {
        pauseCallCount += 1
        await pauseBarrier.suspendIfArmed()
    }

    func stop() async {
        stopCallCount += 1
        await stopBarrier.suspendIfArmed()
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

    func failNextPrepare() { shouldFailNextPrepare = true }
    func failNextPlay() { shouldFailNextPlay = true }
    func suspendNextStops(count: Int) async { await stopBarrier.arm(expected: count) }
    func waitUntilStopsAreSuspended() async { await stopBarrier.waitUntilSuspended() }
    func releaseSuspendedStops() async { await stopBarrier.release() }
    func suspendNextPauses(count: Int) async { await pauseBarrier.arm(expected: count) }
    func waitUntilPausesAreSuspended() async { await pauseBarrier.waitUntilSuspended() }
    func releaseSuspendedPauses() async { await pauseBarrier.release() }
}

private actor TestProgress {
    private struct Key: Hashable, Sendable {
        let courseID: CourseID
        let mode: StudyMode
    }

    private var storage: [Key: [EntryID: Int]] = [:]
    private var completionCounts: [CourseID: Int] = [:]
    private var completionIDs: Set<String> = []
    private var shouldFailNextReset = false
    private let snapshotSuspension = OneShotSuspension()
    private let masterSuspension = OneShotSuspension()
    private let resetSuspension = OneShotSuspension()
    private let completeSuspension = OneShotSuspension()

    nonisolated var client: StudyProgressClient {
        StudyProgressClient(
            snapshot: { [weak self] courseID, mode in
                await self?.snapshot(courseID: courseID, mode: mode) ?? [:]
            },
            record: { [weak self] courseID, mode, entryID in
                await self?.record(courseID: courseID, mode: mode, entryID: entryID) ?? 0
            },
            master: { [weak self] courseID, mode, entryID in
                await self?.master(courseID: courseID, mode: mode, entryID: entryID) ?? 0
            },
            reset: { [weak self] courseID, mode in
                try await self?.reset(courseID: courseID, mode: mode)
            },
            completions: { [weak self] in await self?.completionCounts ?? [:] },
            complete: { [weak self] courseID, completionID in
                await self?.complete(courseID: courseID, completionID: completionID) ?? 0
            }
        )
    }

    func counts(courseID: CourseID, mode: StudyMode) -> [EntryID: Int] {
        storage[Key(courseID: courseID, mode: mode), default: [:]]
    }

    func completions() -> [CourseID: Int] { completionCounts }
    func failNextReset() { shouldFailNextReset = true }
    func seedMastered(courseID: CourseID, mode: StudyMode, entries: [EntryID]) {
        storage[Key(courseID: courseID, mode: mode)] = Dictionary(
            uniqueKeysWithValues: entries.map { ($0, 3) }
        )
    }

    func suspendNextSnapshot() async { await snapshotSuspension.arm() }
    func waitUntilSnapshotIsSuspended() async { await snapshotSuspension.waitUntilSuspended() }
    func releaseSuspendedSnapshot() async { await snapshotSuspension.release() }
    func suspendNextMaster() async { await masterSuspension.arm() }
    func waitUntilMasterIsSuspended() async { await masterSuspension.waitUntilSuspended() }
    func releaseSuspendedMaster() async { await masterSuspension.release() }
    func suspendNextReset() async { await resetSuspension.arm() }
    func waitUntilResetIsSuspended() async { await resetSuspension.waitUntilSuspended() }
    func releaseSuspendedReset() async { await resetSuspension.release() }
    func suspendNextComplete() async { await completeSuspension.arm() }
    func waitUntilCompleteIsSuspended() async { await completeSuspension.waitUntilSuspended() }
    func releaseSuspendedComplete() async { await completeSuspension.release() }

    private func snapshot(courseID: CourseID, mode: StudyMode) async -> [EntryID: Int] {
        await snapshotSuspension.suspendIfArmed()
        return storage[Key(courseID: courseID, mode: mode), default: [:]]
    }

    private func record(courseID: CourseID, mode: StudyMode, entryID: EntryID) -> Int {
        let key = Key(courseID: courseID, mode: mode)
        let count = min(3, storage[key, default: [:]][entryID, default: 0] + 1)
        storage[key, default: [:]][entryID] = count
        return count
    }

    private func master(courseID: CourseID, mode: StudyMode, entryID: EntryID) async -> Int {
        await masterSuspension.suspendIfArmed()
        let key = Key(courseID: courseID, mode: mode)
        storage[key, default: [:]][entryID] = 3
        return 3
    }

    private func reset(courseID: CourseID, mode: StudyMode) async throws {
        await resetSuspension.suspendIfArmed()
        if shouldFailNextReset {
            shouldFailNextReset = false
            throw TestError.forcedFailure
        }
        storage[Key(courseID: courseID, mode: mode)] = [:]
    }

    private func complete(courseID: CourseID, completionID: String) async -> Int {
        await completeSuspension.suspendIfArmed()
        guard completionIDs.insert(completionID).inserted else {
            return completionCounts[courseID, default: 0]
        }
        completionCounts[courseID, default: 0] += 1
        return completionCounts[courseID, default: 0]
    }
}

private actor OneShotSuspension {
    private var isArmed = false
    private var isSuspended = false
    private var suspendedContinuation: CheckedContinuation<Void, Never>?
    private var observerContinuations: [CheckedContinuation<Void, Never>] = []

    func arm() {
        isArmed = true
        isSuspended = false
    }

    func suspendIfArmed() async {
        guard isArmed else { return }
        isArmed = false
        isSuspended = true
        let observers = observerContinuations
        observerContinuations.removeAll()
        observers.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            suspendedContinuation = continuation
        }
    }

    func waitUntilSuspended() async {
        if isSuspended { return }
        await withCheckedContinuation { continuation in
            observerContinuations.append(continuation)
        }
    }

    func release() {
        isSuspended = false
        let continuation = suspendedContinuation
        suspendedContinuation = nil
        continuation?.resume()
    }
}

private actor CountedSuspension {
    private var expected = 0
    private var arrivals = 0
    private var suspendedContinuations: [CheckedContinuation<Void, Never>] = []
    private var observerContinuations: [CheckedContinuation<Void, Never>] = []

    func arm(expected: Int) {
        self.expected = max(0, expected)
        arrivals = 0
    }

    func suspendIfArmed() async {
        guard expected > 0, arrivals < expected else { return }
        arrivals += 1
        if arrivals == expected {
            let observers = observerContinuations
            observerContinuations.removeAll()
            observers.forEach { $0.resume() }
        }
        await withCheckedContinuation { continuation in
            suspendedContinuations.append(continuation)
        }
    }

    func waitUntilSuspended() async {
        if expected > 0, arrivals == expected { return }
        await withCheckedContinuation { continuation in
            observerContinuations.append(continuation)
        }
    }

    func release() {
        expected = 0
        arrivals = 0
        let continuations = suspendedContinuations
        suspendedContinuations.removeAll()
        continuations.forEach { $0.resume() }
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
