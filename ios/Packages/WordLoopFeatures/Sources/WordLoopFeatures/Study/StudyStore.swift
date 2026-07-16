import Foundation
import Observation
import WordLoopAudio
import WordLoopCore
import WordLoopDesignSystem

@MainActor
@Observable
public final class StudyStore {
    public private(set) var state = StudyState()

    let shellStore = StudyShellStore()
    let courseDrawerStore = CourseDrawerStore()
    let progressDrawerStore = ProgressDrawerStore()
    let completionDialogStore = CompletionDialogStore()

    private let courses: StudyCourseClient
    private let audio: StudyAudioClient
    private let progress: StudyProgressClient
    private let clock: StudyClock
    private let random: StudyRandomClient

    private var catalog: CourseCatalog?
    private var course: Course?
    private var collection: CourseCollectionDescriptor?
    private var currentEntryID: EntryID?
    private var mode: StudyMode = .repeat
    private nonisolated let eventTask = StudyTaskSlot()
    private nonisolated let waitingTask = StudyTaskSlot()
    private var hasStarted = false
    private var failedCourseID: CourseID?

    init(
        courses: StudyCourseClient,
        audio: StudyAudioClient,
        progress: StudyProgressClient,
        clock: StudyClock = .live,
        random: StudyRandomClient = .live
    ) {
        self.courses = courses
        self.audio = audio
        self.progress = progress
        self.clock = clock
        self.random = random
        observeAudioEvents()
    }

    public func start() async {
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
            failedCourseID = catalog.defaultCourseID
            try await loadCourse(id: catalog.defaultCourseID, generation: generation)
        } catch {
            guard isCurrent(generation) else { return }
            hasStarted = false
            state.phase = .failed
            state.listenPhase = .failed
        }
    }

    public func playCurrent() async {
        guard mode == .listen, let course, let currentEntryID else { return }
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
            try await loadCourse(id: courseID, generation: generation)
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

    private func loadCourse(id: CourseID, generation: ListenSessionGeneration) async throws {
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
                selectedCourseID: id
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
            selectedCourseID: id
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
            selectedCourseID: course.id
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

    private var currentAudioURL: URL? {
        guard let course, let currentEntryID else { return nil }
        return course.entries.first(where: { $0.id == currentEntryID })?.audioURL
    }
}
