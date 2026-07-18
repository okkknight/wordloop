import Foundation
import Observation
import WordLoopAudio
import WordLoopCore
import WordLoopDesignSystem
import WordLoopRealtime

@MainActor
@Observable
public final class StudyStore {
    private static let repeatPlaybackTimeout: Duration = .seconds(8)
    private static let repeatSpeakTimeout: Duration = .seconds(6)
    private static let repeatSpeakingTimeout: Duration = .seconds(6)
    private static let repeatScoringTimeout: Duration = .seconds(6)
    private static let repeatRetryDelay: Duration = .milliseconds(850)
    public private(set) var state = StudyState()

    let shellStore = StudyShellStore()
    let courseDrawerStore = CourseDrawerStore()
    let progressDrawerStore = ProgressDrawerStore()
    let completionDialogStore = CompletionDialogStore()

    private let courses: StudyCourseClient
    private let audio: StudyAudioClient
    private let progress: StudyProgressClient
    private let realtime: StudyRealtimeClient
    private let clock: StudyClock
    private let random: StudyRandomClient
    private let courseSelection: @Sendable (CourseID, StudyMode) async -> Void

    private var catalog: CourseCatalog?
    private var course: Course?
    private var collection: CourseCollectionDescriptor?
    private var currentEntryID: EntryID?
    private var mode: StudyMode = .repeat
    private var completionCounts: [CourseID: Int] = [:]
    private var settledCompletions: Set<CourseModeKey> = []
    private nonisolated let eventTask = StudyTaskSlot()
    private nonisolated let waitingTask = StudyTaskSlot()
    private nonisolated let repeatPhaseTask = StudyTaskSlot()
    private var hasStarted = false
    private var failedCourseID: CourseID?
    private var repeatController = RepeatSessionController()
    private var repeatPlaybackRequestID: PlaybackRequestID?
    private var realtimeConnected = false
    private var microphoneAuthorized = false

    init(
        courses: StudyCourseClient,
        audio: StudyAudioClient,
        progress: StudyProgressClient,
        realtime: StudyRealtimeClient = .unavailable,
        clock: StudyClock = .live,
        random: StudyRandomClient = .live,
        courseSelection: @escaping @Sendable (CourseID, StudyMode) async -> Void = { _, _ in }
    ) {
        self.courses = courses
        self.audio = audio
        self.progress = progress
        self.realtime = realtime
        self.clock = clock
        self.random = random
        self.courseSelection = courseSelection
        observeAudioEvents()
    }

    public func start(preferredCourseID: CourseID? = nil) async {
        guard !hasStarted else { return }
        hasStarted = true
        failedCourseID = nil
        let generation = beginNewSession()
        state.phase = .loading
        await audio.stop()

        do {
            let catalog = try await courses.catalog()
            guard isCurrent(generation) else { return }
            self.catalog = catalog
            completionCounts = await progress.completions()
            guard isCurrent(generation) else { return }
            let initialCourseID = preferredCourseID.flatMap { preferred in
                catalog.courses.contains(where: { $0.id == preferred && $0.availability == .available }) ? preferred : nil
            } ?? catalog.defaultCourseID
            failedCourseID = initialCourseID
            try await loadCourse(id: initialCourseID, generation: generation)
        } catch {
            guard isCurrent(generation) else { return }
            hasStarted = false
            state.phase = .failed
            state.listenPhase = .failed
        }
    }

    public func playCurrent() async {
        if mode == .repeat {
            await startRepeatTurn()
            return
        }
        guard let course, let currentEntryID else { return }
        let generation = beginNewSession()
        await audio.stop()
        await playRound(
            course: course,
            entryID: currentEntryID,
            generation: generation,
            recordsProgress: false
        )
    }

    public func selectCourse(_ rawCourseID: String) async {
        guard let courseID = CourseID(rawValue: rawCourseID), catalog != nil else { return }
        let generation = beginNewSession()
        failedCourseID = courseID
        state.phase = .loading
        await audio.stop()
        do {
            try await loadCourse(id: courseID, generation: generation, promptsForCompletedCourse: true)
            guard isCurrent(generation), state.selectedCourseID == courseID else { return }
            await courseSelection(courseID, mode)
        } catch {
            guard isCurrent(generation) else { return }
            state.phase = .failed
            state.listenPhase = .failed
        }
    }

    public func retry() async {
        guard state.phase == .failed else { return }
        if let failedCourseID {
            await selectCourse(failedCourseID.rawValue)
        } else {
            hasStarted = false
            await start()
        }
    }

    public func selectMode(_ shellMode: StudyShellMode) async {
        guard state.phase != .loading else { return }
        let requested: StudyMode = shellMode == .listen ? .listen : .repeat
        guard requested != mode else { return }
        mode = requested
        let generation = beginNewSession()
        await audio.stop()
        guard isCurrent(generation), mode == requested else { return }
        shellStore.state.mode = shellMode

        guard let course, let currentEntryID else { return }
        if requested == .listen {
            await playRound(
                course: course,
                entryID: currentEntryID,
                generation: generation,
                recordsProgress: true
            )
        } else {
            state.listenPhase = .idle
            state.activePlaybackRequestID = nil
            await refreshProjection(
                course: course,
                currentEntryID: currentEntryID,
                generation: generation
            )
            await startRepeatTurn()
        }
    }

    public func cycleVisibility() {
        shellStore.cycleVisibility()
    }

    public func next() async {
        guard mode == .listen, let course, let activeEntryID = currentEntryID else { return }
        let generation = beginNewSession()
        await audio.stop()
        guard sessionMatches(generation, courseID: course.id, entryID: activeEntryID) else { return }
        await advance(
            from: activeEntryID,
            in: course,
            generation: generation
        )
    }

    public func toggleAutoplay() async {
        guard mode == .listen else { return }
        state.isAutoplayEnabled.toggle()
        shellStore.state.isAutoplayEnabled = state.isAutoplayEnabled
        guard !state.isAutoplayEnabled else { return }
        if state.listenPhase == .waiting {
            cancelWaitingAndAdvanceGeneration()
            state.listenPhase = .idle
        } else {
            waitingTask.cancel()
        }
    }

    public func markTooEasy() async {
        guard mode == .listen, let course, let currentEntryID else { return }
        let generation = beginNewSession()
        await audio.stop()
        guard sessionMatches(generation, courseID: course.id, entryID: currentEntryID) else { return }
        _ = await progress.master(course.id, mode, currentEntryID)
        guard sessionMatches(generation, courseID: course.id, entryID: currentEntryID) else { return }
        await advance(
            from: currentEntryID,
            in: course,
            generation: generation
        )
    }

    public func setApplicationActive(_ isActive: Bool) async {
        guard !isActive else { return }
        let generation = beginNewSession()
        await audio.pause()
        realtime.setMicrophoneEnabled(false)
        if mode == .repeat {
            _ = repeatController.pause()
            state.repeatPhase = .paused
            applyRepeatPresentation(.paused)
        }
        guard isCurrent(generation) else { return }
        state.activePlaybackRequestID = nil
        if state.phase == .loading {
            hasStarted = catalog != nil
            state.phase = .failed
            state.listenPhase = .failed
        } else if state.listenPhase == .playing || state.listenPhase == .waiting {
            state.listenPhase = .paused
        }
    }

    public func restartCourse(_ rawCourseID: String) async {
        guard let courseID = CourseID(rawValue: rawCourseID), catalog != nil else { return }
        let resetMode = mode
        let generation = beginNewSession()
        await audio.stop()
        guard isCurrent(generation), mode == resetMode else { return }

        do {
            try await progress.reset(courseID, resetMode)
            guard isCurrent(generation), mode == resetMode else { return }
            settledCompletions.remove(.init(courseID: courseID, mode: resetMode))
            completionDialogStore.requestRestart()
            try await loadCourse(id: courseID, generation: generation)
        } catch {
            guard isCurrent(generation), mode == resetMode else { return }
            state.phase = .ready
            state.listenPhase = .failed
            completionDialogStore.state.errorMessage = CompletionDialogViewState.fixedErrorMessage
            completionDialogStore.state.isPresented = true
        }
    }

    private func loadCourse(
        id: CourseID,
        generation: ListenSessionGeneration,
        promptsForCompletedCourse: Bool = false
    ) async throws {
        let loaded = try await courses.course(id)
        guard isCurrent(generation), let catalog else { return }
        let counts = await progress.snapshot(id, mode)
        guard isCurrent(generation) else { return }
        guard let first = StudySelection.entry(
            in: loaded.entries,
            order: loaded.descriptor.practiceOrder,
            studyCounts: counts,
            excluding: nil,
            randomIndex: random.index(max(1, loaded.entries.count))
        ) else {
            if promptsForCompletedCourse {
                state.phase = .ready
                state.listenPhase = .idle
                completionDialogStore.present(
                    kind: .restartCompletedCourse,
                    courseID: id.rawValue
                )
                return
            }
            course = loaded
            collection = catalog.collections.first(where: { $0.id == loaded.descriptor.collectionID })
            let fallbackEntryID = loaded.entries.first?.id
            currentEntryID = fallbackEntryID
            failedCourseID = nil
            state.selectedCourseID = id
            state.currentEntryID = fallbackEntryID
            state.nextEntryID = nil
            state.courseExhausted = true
            state.phase = .ready
            courseDrawerStore.state = StudyProjection.courseDrawerState(
                catalog: catalog,
                selectedCourseID: id,
                completionCounts: completionCounts
            )
            if let fallbackEntryID {
                await refreshProjection(
                    course: loaded,
                    currentEntryID: fallbackEntryID,
                    generation: generation
                )
                guard isCurrent(generation),
                      self.course?.id == loaded.id,
                      currentEntryID == fallbackEntryID else { return }
            }
            state.listenPhase = .idle
            return
        }

        course = loaded
        collection = catalog.collections.first(where: { $0.id == loaded.descriptor.collectionID })
        currentEntryID = first.id
        failedCourseID = nil
        state.selectedCourseID = id
        state.currentEntryID = first.id
        state.courseExhausted = false
        state.phase = .ready
        courseDrawerStore.state = StudyProjection.courseDrawerState(
            catalog: catalog,
            selectedCourseID: id,
            completionCounts: completionCounts
        )
        await refreshProjection(
            course: loaded,
            currentEntryID: first.id,
            generation: generation
        )
        guard isCurrent(generation),
              self.course?.id == loaded.id,
              currentEntryID == first.id else { return }

        if mode == .listen {
            await playRound(
                course: loaded,
                entryID: first.id,
                generation: generation,
                recordsProgress: true
            )
        } else {
            state.listenPhase = .idle
        }
    }

    private func playRound(
        course: Course,
        entryID: EntryID,
        generation: ListenSessionGeneration,
        recordsProgress: Bool
    ) async {
        guard sessionMatches(generation, courseID: course.id, entryID: entryID),
              let entry = course.entries.first(where: { $0.id == entryID }) else { return }

        if recordsProgress {
            _ = await progress.record(course.id, .listen, entryID)
            guard sessionMatches(generation, courseID: course.id, entryID: entryID) else { return }
        }
        currentEntryID = entryID
        await refreshProjection(
            course: course,
            currentEntryID: entryID,
            generation: generation
        )
        guard sessionMatches(generation, courseID: course.id, entryID: entryID) else { return }

        let counts = await progress.snapshot(course.id, .listen)
        guard sessionMatches(generation, courseID: course.id, entryID: entryID) else { return }
        let next = StudySelection.entry(
            in: course.entries,
            order: course.descriptor.practiceOrder,
            studyCounts: counts,
            excluding: entryID,
            randomIndex: random.index(max(1, course.entries.count))
        )
        state.currentEntryID = entryID
        state.nextEntryID = next?.id
        state.courseExhausted = StudySelection.eligibleEntries(
            in: course.entries,
            studyCounts: counts
        ).isEmpty
        state.listenPhase = .preparing

        do {
            try await audio.prepare(entry.audioURL, next?.audioURL)
            guard sessionMatches(generation, courseID: course.id, entryID: entryID) else { return }
            let requestID = try await audio.play()
            guard sessionMatches(generation, courseID: course.id, entryID: entryID) else { return }
            state.activePlaybackRequestID = requestID
            state.listenPhase = .playing
            if state.courseExhausted {
                await settleCompletion(
                    courseID: course.id,
                    entryID: entryID,
                    generation: generation
                )
            }
        } catch {
            guard sessionMatches(generation, courseID: course.id, entryID: entryID) else { return }
            failCurrentListenSession()
        }
    }

    private func refreshProjection(
        course: Course,
        currentEntryID: EntryID,
        generation: ListenSessionGeneration
    ) async {
        guard let collection else { return }
        let projectionMode = mode
        let counts = await progress.snapshot(course.id, projectionMode)
        guard isCurrent(generation),
              mode == projectionMode,
              self.course?.id == course.id,
              self.currentEntryID == currentEntryID else { return }
        let oldVisibility = shellStore.state.visibility
        let oldDrawerPresented = courseDrawerStore.state.isPresented
        let oldDrawerQuery = courseDrawerStore.state.query
        let oldProgressPresented = progressDrawerStore.state.isPresented
        let oldProgressQuery = progressDrawerStore.state.query

        if let shell = StudyProjection.studyShellState(
            course: course,
            collection: collection,
            currentEntryID: currentEntryID,
            palette: shellStore.state.palette,
            mode: projectionMode,
            visibility: oldVisibility,
            masteryCount: counts[currentEntryID, default: 0],
            isAutoplayEnabled: state.isAutoplayEnabled
        ) {
            shellStore.state = shell
        }

        var drawer = StudyProjection.courseDrawerState(
            catalog: catalog ?? CourseCatalog(
                schemaVersion: 1,
                generatedAt: "",
                defaultCourseID: course.id,
                collections: [collection],
                courses: [course.descriptor]
            ),
            selectedCourseID: course.id,
            completionCounts: completionCounts
        )
        drawer.isPresented = oldDrawerPresented
        drawer.query = oldDrawerQuery
        courseDrawerStore.state = drawer

        var progressState = StudyProjection.progressDrawerState(course: course, studyCounts: counts)
        progressState.isPresented = oldProgressPresented
        progressState.query = oldProgressQuery
        progressDrawerStore.state = progressState
    }

    private func observeAudioEvents() {
        let audio = audio
        eventTask.replace(with: Task { [weak self] in
            let events = await audio.events()
            for await event in events {
                guard !Task.isCancelled else { return }
                self?.handleAudioEvent(event)
            }
        })
    }

    private func handleAudioEvent(_ event: AudioPlayerEvent) {
        switch event {
        case .preloadFailed:
            break
        case let .stateChanged(snapshot):
            switch snapshot.phase {
            case .finished:
                if mode == .repeat,
                   let requestID = snapshot.requestID,
                   requestID == repeatPlaybackRequestID {
                    repeatPlaybackRequestID = nil
                    repeatPhaseTask.cancel()
                    if let action = repeatController.playbackFinished(turnID: repeatController.turnID) {
                        handleRepeatAction(action)
                    }
                    return
                }
                guard let requestID = snapshot.requestID,
                      requestID == state.activePlaybackRequestID else { return }
                state.activePlaybackRequestID = nil
                guard state.isAutoplayEnabled else {
                    state.listenPhase = .idle
                    return
                }
                scheduleAutoplayWait(settledRequestID: requestID)
            case .failed:
                guard let requestID = snapshot.requestID,
                      requestID == state.activePlaybackRequestID else { return }
                failCurrentListenSession()
            case .paused:
                guard let requestID = snapshot.requestID,
                      requestID == state.activePlaybackRequestID,
                      snapshot.currentURL == currentAudioURL else { return }
                cancelWaitingAndAdvanceGeneration()
                state.activePlaybackRequestID = nil
                state.listenPhase = .paused
            default:
                break
            }
        }
    }

    private func scheduleAutoplayWait(settledRequestID: PlaybackRequestID) {
        waitingTask.cancel()
        repeatPhaseTask.cancel()
        let binding = SessionBinding(
            generation: state.listenGeneration,
            courseID: state.selectedCourseID,
            entryID: state.currentEntryID,
            requestID: settledRequestID
        )
        state.listenPhase = .waiting
        let clock = clock
        waitingTask.replace(with: Task { [weak self] in
            do {
                try await clock.sleep(.milliseconds(500))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.advanceAfterAutoplay(binding: binding)
        })
    }

    private func advanceAfterAutoplay(binding: SessionBinding) async {
        guard binding.matches(state), state.isAutoplayEnabled else { return }
        await next()
    }

    private func failCurrentListenSession() {
        waitingTask.cancel()
        state.isAutoplayEnabled = false
        state.activePlaybackRequestID = nil
        state.listenPhase = .failed
        shellStore.state.isAutoplayEnabled = false
    }

    @discardableResult
    private func beginNewSession() -> ListenSessionGeneration {
        waitingTask.cancel()
        if repeatController.phase != .idle {
            realtime.setMicrophoneEnabled(false)
            _ = repeatController.invalidate()
            repeatPlaybackRequestID = nil
        }
        state.listenGeneration = .init(rawValue: state.listenGeneration.rawValue &+ 1)
        state.activePlaybackRequestID = nil
        return state.listenGeneration
    }

    private func cancelWaitingAndAdvanceGeneration() {
        _ = beginNewSession()
    }

    private func isCurrent(_ generation: ListenSessionGeneration) -> Bool {
        state.listenGeneration == generation
    }

    private func sessionMatches(
        _ generation: ListenSessionGeneration,
        courseID: CourseID,
        entryID: EntryID
    ) -> Bool {
        isCurrent(generation)
            && mode == .listen
            && course?.id == courseID
            && currentEntryID == entryID
    }

    private func advance(
        from activeEntryID: EntryID,
        in course: Course,
        generation: ListenSessionGeneration
    ) async {
        guard sessionMatches(generation, courseID: course.id, entryID: activeEntryID) else { return }
        let counts = await progress.snapshot(course.id, .listen)
        guard sessionMatches(generation, courseID: course.id, entryID: activeEntryID) else { return }
        guard let selected = StudySelection.entry(
            in: course.entries,
            order: course.descriptor.practiceOrder,
            studyCounts: counts,
            excluding: activeEntryID,
            randomIndex: random.index(max(1, course.entries.count))
        ) else {
            state.courseExhausted = true
            return
        }

        currentEntryID = selected.id
        chooseNextPalette()
        await playRound(
            course: course,
            entryID: selected.id,
            generation: generation,
            recordsProgress: true
        )
    }

    private func chooseNextPalette() {
        if let palette = StudySelection.palette(
            from: PosterPalette.all,
            excluding: shellStore.state.palette.id,
            randomIndex: random.index(max(1, PosterPalette.all.count))
        ) {
            shellStore.state.palette = palette
        }
    }

    private func settleCompletion(
        courseID: CourseID,
        entryID: EntryID,
        generation: ListenSessionGeneration
    ) async {
        let key = CourseModeKey(courseID: courseID, mode: mode)
        guard settledCompletions.insert(key).inserted else { return }
        let completionID = UUID().uuidString
        do {
            let count = try await progress.complete(courseID, completionID)
            guard sessionMatches(generation, courseID: courseID, entryID: entryID) else { return }
            completionCounts[courseID] = count
            if let catalog {
                courseDrawerStore.state = StudyProjection.courseDrawerState(
                    catalog: catalog,
                    selectedCourseID: courseID,
                    completionCounts: completionCounts
                )
            }
            completionDialogStore.present(kind: .courseCompleted, courseID: courseID.rawValue)
        } catch {
            settledCompletions.remove(key)
        }
    }

    private var currentAudioURL: URL? {
        guard let course, let currentEntryID else { return nil }
        return course.entries.first(where: { $0.id == currentEntryID })?.audioURL
    }

    public func toggleRepeatPause() async {
        guard mode == .repeat else { return }
        if state.repeatPhase == .paused {
            await startRepeatTurn()
        } else {
            await audio.pause()
            realtime.setMicrophoneEnabled(false)
            _ = repeatController.pause()
            state.repeatPhase = .paused
            applyRepeatPresentation(.paused)
        }
    }

    private func startRepeatTurn() async {
        guard mode == .repeat,
              let course,
              let entryID = currentEntryID,
              let entry = course.entries.first(where: { $0.id == entryID }) else { return }

        state.repeatPhase = .connecting
        applyRepeatPresentation(.connecting)
        realtime.setMicrophoneEnabled(false)

        if !microphoneAuthorized {
            microphoneAuthorized = await realtime.requestPermission()
        }
        guard microphoneAuthorized else {
            state.repeatPhase = .failed
            applyRepeatPresentation(.error)
            return
        }
        if !realtimeConnected {
            do {
                try await realtime.connect(
                    { [weak self] event in
                        Task { @MainActor in self?.handleRealtimeEvent(event) }
                    },
                    { [weak self] connectionState in
                        Task { @MainActor in self?.handleRealtimeState(connectionState) }
                    }
                )
                realtimeConnected = true
            } catch {
                state.repeatPhase = .failed
                applyRepeatPresentation(.error)
                return
            }
        }
        let turn = repeatController.beginTurn()
        state.repeatPhase = .playing
        shellStore.state.repeatTranscript = nil
        applyRepeatPresentation(.playing)
        do {
            try await audio.prepare(entry.audioURL, nil)
            try await audio.configureForRepeat()
            guard mode == .repeat, currentEntryID == entryID, repeatController.turnID == turn else { return }
            repeatPlaybackRequestID = try await audio.play()
            scheduleRepeatTimeout(
                turnID: turn,
                phase: .playing,
                duration: Self.repeatPlaybackTimeout
            )
        } catch {
            state.repeatPhase = .retry
            applyRepeatPresentation(.retry)
        }
    }

    private func handleRealtimeState(_ connectionState: RealtimePeerConnectionState) {
        switch connectionState {
        case .ready:
            repeatController.connected()
        case .failed:
            state.repeatPhase = .failed
            applyRepeatPresentation(.error)
        case .disconnected:
            realtimeConnected = false
        case .connecting:
            break
        }
    }

    private func handleRealtimeEvent(_ event: RealtimeTransportEvent) {
        guard mode == .repeat else { return }
        let action = repeatController.receive(event, turnID: repeatController.turnID)
        syncRepeatPhase()
        switch repeatController.phase {
        case .speaking:
            scheduleRepeatTimeout(
                turnID: repeatController.turnID,
                phase: .speaking,
                duration: Self.repeatSpeakingTimeout
            )
        case .scoring:
            scheduleRepeatTimeout(
                turnID: repeatController.turnID,
                phase: .scoring,
                duration: Self.repeatScoringTimeout
            )
        default:
            break
        }
        guard let action else { return }
        handleRepeatAction(action)
    }

    private func handleRepeatAction(_ action: RepeatSessionAction) {
        switch action {
        case .enableMicrophone:
            realtime.setMicrophoneEnabled(true)
            state.repeatPhase = .armed
            applyRepeatPresentation(.speak)
            scheduleRepeatTimeout(
                turnID: repeatController.turnID,
                phase: .armed,
                duration: Self.repeatSpeakTimeout
            )
        case .disableMicrophone:
            realtime.setMicrophoneEnabled(false)
            state.repeatPhase = repeatController.phase == .retry ? .retry : .scoring
            applyRepeatPresentation(state.repeatPhase == .retry ? .retry : .scoring)
        case let .score(turnID, _, transcript):
            repeatPhaseTask.cancel()
            guard let course,
                  let entryID = currentEntryID,
                  let entry = course.entries.first(where: { $0.id == entryID }) else { return }
            let result = RepeatScorer.score(
                target: entry.text,
                transcript: transcript,
                sentence: course.descriptor.kind == .sentence
            )
            repeatController.scored(turnID: turnID, passed: result.passed)
            state.repeatPhase = result.passed ? .passed : .retry
            shellStore.state.repeatTranscript = result.passed ? nil : transcript
            applyRepeatPresentation(result.passed ? .passed : .retry)
            guard result.passed else {
                scheduleRepeatRetry(turnID: turnID)
                return
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                _ = await self.progress.record(course.id, .repeat, entryID)
                guard self.mode == .repeat,
                      self.currentEntryID == entryID,
                      self.repeatController.turnID == turnID else { return }
                await self.advanceRepeat(from: entryID, in: course)
            }
        }
    }

    private func advanceRepeat(from entryID: EntryID, in course: Course) async {
        let counts = await progress.snapshot(course.id, .repeat)
        guard mode == .repeat, currentEntryID == entryID else { return }
        guard let next = StudySelection.entry(
            in: course.entries,
            order: course.descriptor.practiceOrder,
            studyCounts: counts,
            excluding: entryID,
            randomIndex: random.index(max(1, course.entries.count))
        ) else { return }
        currentEntryID = next.id
        state.currentEntryID = next.id
        chooseNextPalette()
        await refreshProjection(course: course, currentEntryID: next.id, generation: state.listenGeneration)
        await startRepeatTurn()
    }

    private func applyRepeatPresentation(_ presentation: StudyRepeatPresentationState) {
        shellStore.state.repeatPresentationState = presentation
        shellStore.state.isRepeatPaused = presentation == .paused
    }

    private func scheduleRepeatTimeout(
        turnID: UInt64,
        phase: RepeatSessionPhase,
        duration: Duration
    ) {
        repeatPhaseTask.replace(with: Task { [weak self] in
            do { try await Task.sleep(for: duration) } catch { return }
            await self?.retryRepeatIfCurrent(turnID: turnID, phase: phase)
        })
    }

    private func scheduleRepeatRetry(turnID: UInt64) {
        repeatPhaseTask.replace(with: Task { [weak self] in
            do { try await Task.sleep(for: Self.repeatRetryDelay) } catch { return }
            guard let self, self.mode == .repeat, self.repeatController.turnID == turnID else { return }
            await self.startRepeatTurn()
        })
    }

    private func retryRepeatIfCurrent(turnID: UInt64, phase: RepeatSessionPhase) async {
        guard mode == .repeat,
              repeatController.turnID == turnID,
              repeatController.phase == phase else { return }
        realtime.setMicrophoneEnabled(false)
        _ = repeatController.invalidate()
        state.repeatPhase = .retry
        applyRepeatPresentation(.retry)
        scheduleRepeatRetry(turnID: repeatController.turnID)
    }

    private func syncRepeatPhase() {
        let presentation: StudyRepeatPresentationState
        switch repeatController.phase {
        case .idle: presentation = .idle
        case .connecting: presentation = .connecting
        case .ready: presentation = .ready
        case .playing: presentation = .playing
        case .armed: presentation = .speak
        case .speaking: presentation = .speaking
        case .scoring: presentation = .scoring
        case .passed: presentation = .passed
        case .retry: presentation = .retry
        case .paused: presentation = .paused
        case .recoverableError: presentation = .error
        }
        state.repeatPhase = switch repeatController.phase {
        case .idle: .idle
        case .connecting, .ready: .connecting
        case .playing: .playing
        case .armed: .armed
        case .speaking: .speaking
        case .scoring: .scoring
        case .passed: .passed
        case .retry: .retry
        case .paused: .paused
        case .recoverableError: .failed
        }
        applyRepeatPresentation(presentation)
    }
}

private struct CourseModeKey: Hashable {
    let courseID: CourseID
    let mode: StudyMode
}
