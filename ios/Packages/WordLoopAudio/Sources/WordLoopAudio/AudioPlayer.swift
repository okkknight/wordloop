import Foundation

public actor AudioPlayer {
    private let engineFactory: any AudioEngineFactory
    private let session: any AudioSessionControlling
    private let systemEventSource: any AudioSystemEventSource
    private let requestIDGenerator: PlaybackRequestIDGenerator

    private var currentSlot: AudioEngineSlot?
    private var nextSlot: AudioEngineSlot?
    private var activeRequestID: PlaybackRequestID?
    private var currentSnapshot = AudioPlaybackSnapshot(
        phase: .idle,
        currentURL: nil,
        nextURL: nil,
        requestID: nil,
        pauseReason: nil,
        error: nil
    )
    private var subscribers: [UUID: AsyncStream<AudioPlayerEvent>.Continuation] = [:]
    private var observesSystemEvents = false

    public static func live() throws -> AudioPlayer {
        #if os(iOS)
        return AudioPlayer(
            engineFactory: AVAudioEngineFactory(),
            session: IOSAudioSessionController(),
            systemEventSource: IOSAudioSystemEventSource()
        )
        #else
        throw AudioPlayerError.unsupportedPlatform
        #endif
    }

    init(
        engineFactory: any AudioEngineFactory,
        session: any AudioSessionControlling,
        systemEventSource: any AudioSystemEventSource,
        requestIDGenerator: PlaybackRequestIDGenerator = .init()
    ) {
        self.engineFactory = engineFactory
        self.session = session
        self.systemEventSource = systemEventSource
        self.requestIDGenerator = requestIDGenerator
    }

    deinit {
        systemEventSource.setHandler(nil)
        for continuation in subscribers.values {
            continuation.finish()
        }
    }

    public func prepare(current: URL, next: URL?) async throws {
        startObservingSystemEventsIfNeeded()
        let wasPlaying = currentSnapshot.phase == .playing
        invalidateActiveRequest()
        if wasPlaying {
            session.deactivate()
        }

        let normalizedCurrent: URL
        do {
            normalizedCurrent = try validateLocalAudioURL(current)
        } catch let error as AudioPlayerError {
            clearSlots()
            transition(to: .failed, error: error)
            throw error
        } catch {
            clearSlots()
            transition(to: .failed, error: .couldNotPrepare)
            throw AudioPlayerError.couldNotPrepare
        }

        let oldCurrent = currentSlot
        let oldNext = nextSlot
        var preparedCurrent: AudioEngineSlot?

        if oldNext?.url == normalizedCurrent {
            oldCurrent?.engine.stop()
            oldCurrent?.engine.clearCallbacks()
            preparedCurrent = oldNext
            preparedCurrent?.engine.currentTime = 0
        } else if oldCurrent?.url == normalizedCurrent {
            oldCurrent?.engine.stop()
            oldCurrent?.engine.clearCallbacks()
            oldCurrent?.engine.currentTime = 0
            preparedCurrent = oldCurrent
            if oldNext?.id != oldCurrent?.id {
                oldNext?.engine.stop()
                oldNext?.engine.clearCallbacks()
            }
        } else {
            clearSlots()
            do {
                preparedCurrent = try makePreparedSlot(url: normalizedCurrent)
            } catch let error as AudioPlayerError {
                transition(to: .failed, error: error)
                throw error
            } catch {
                transition(to: .failed, error: .couldNotPrepare)
                throw AudioPlayerError.couldNotPrepare
            }
        }

        currentSlot = preparedCurrent
        nextSlot = nil

        if let next {
            do {
                let normalizedNext = try validateLocalAudioURL(next)
                if normalizedNext == normalizedCurrent {
                    publish(.preloadFailed(next, .invalidState))
                } else if let oldNext,
                          oldNext.id != preparedCurrent?.id,
                          oldNext.url == normalizedNext {
                    nextSlot = oldNext
                    nextSlot?.engine.currentTime = 0
                } else {
                    nextSlot = try makePreparedSlot(url: normalizedNext)
                }
            } catch let error as AudioPlayerError {
                publish(.preloadFailed(next, error))
            } catch {
                publish(.preloadFailed(next, .couldNotPrepare))
            }
        }

        if let oldNext,
           oldNext.id != currentSlot?.id,
           oldNext.id != nextSlot?.id {
            oldNext.engine.stop()
            oldNext.engine.clearCallbacks()
        }
        transition(to: .prepared)
    }

    @discardableResult
    public func play() async throws -> PlaybackRequestID {
        startObservingSystemEventsIfNeeded()
        guard let currentSlot,
              [.prepared, .paused, .finished].contains(currentSnapshot.phase) else {
            throw AudioPlayerError.invalidState
        }

        if currentSnapshot.phase == .finished {
            currentSlot.engine.currentTime = 0
        }

        do {
            try session.configureForSpokenPlayback()
            try session.activate()
        } catch {
            invalidateActiveRequest()
            session.deactivate()
            transition(to: .failed, error: .sessionActivationFailed)
            throw AudioPlayerError.sessionActivationFailed
        }

        let requestID = requestIDGenerator.next()
        activeRequestID = requestID
        let engineID = currentSlot.id
        currentSlot.engine.installCallbacks(
            onFinish: { [weak self] in
                await self?.settleFinish(engineID: engineID, requestID: requestID)
            },
            onDecodeFailure: { [weak self] in
                await self?.settleFailure(engineID: engineID, requestID: requestID)
            }
        )

        guard currentSlot.engine.play() else {
            invalidateActiveRequest()
            session.deactivate()
            transition(to: .failed, requestID: requestID, error: .playbackStartFailed)
            throw AudioPlayerError.playbackStartFailed
        }

        transition(to: .playing, requestID: requestID)
        return requestID
    }

    public func pause() async {
        pause(reason: .user)
    }

    public func stop() async {
        startObservingSystemEventsIfNeeded()
        invalidateActiveRequest()
        clearSlots()
        session.deactivate()
        transition(to: .stopped)
    }

    public func snapshot() async -> AudioPlaybackSnapshot {
        currentSnapshot
    }

    public func events() async -> AsyncStream<AudioPlayerEvent> {
        startObservingSystemEventsIfNeeded()
        let subscriberID = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(64)) { continuation in
            subscribers[subscriberID] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeSubscriber(subscriberID) }
            }
        }
    }

    func subscriberCount() -> Int {
        subscribers.count
    }

    func preparedEngineCount() -> Int {
        Set([currentSlot?.id, nextSlot?.id].compactMap { $0 }).count
    }

    private func startObservingSystemEventsIfNeeded() {
        guard !observesSystemEvents else { return }
        observesSystemEvents = true
        systemEventSource.setHandler { [weak self] event in
            await self?.handleSystemEvent(event)
        }
    }

    private func validateLocalAudioURL(_ url: URL) throws -> URL {
        guard url.isFileURL else { throw AudioPlayerError.invalidLocalURL }
        let normalized = url.standardizedFileURL
        guard FileManager.default.fileExists(atPath: normalized.path) else {
            throw AudioPlayerError.fileMissing
        }
        let values: URLResourceValues
        do {
            values = try normalized.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
        } catch {
            throw AudioPlayerError.fileMissing
        }
        guard values.isSymbolicLink != true, values.isRegularFile == true else {
            throw AudioPlayerError.nonRegularFile
        }
        return normalized
    }

    private func makePreparedSlot(url: URL) throws -> AudioEngineSlot {
        let engine: any AudioEngine
        do {
            engine = try engineFactory.makeEngine(url: url)
        } catch {
            throw AudioPlayerError.couldNotPrepare
        }
        engine.currentTime = 0
        guard engine.prepareToPlay() else {
            engine.stop()
            engine.clearCallbacks()
            throw AudioPlayerError.couldNotPrepare
        }
        return AudioEngineSlot(engine: engine)
    }

    private func pause(reason: AudioPauseReason) {
        guard currentSnapshot.phase == .playing else { return }
        currentSlot?.engine.pause()
        let requestID = activeRequestID
        invalidateActiveRequest()
        session.deactivate()
        transition(to: .paused, requestID: requestID, pauseReason: reason)
    }

    private func settleFinish(engineID: UUID, requestID: PlaybackRequestID) {
        guard currentSlot?.id == engineID, activeRequestID == requestID else { return }
        invalidateActiveRequest()
        session.deactivate()
        transition(to: .finished, requestID: requestID)
    }

    private func settleFailure(engineID: UUID, requestID: PlaybackRequestID) {
        guard currentSlot?.id == engineID, activeRequestID == requestID else { return }
        invalidateActiveRequest()
        session.deactivate()
        transition(to: .failed, requestID: requestID, error: .decodeFailed)
    }

    private func handleSystemEvent(_ event: AudioSystemEvent) {
        switch event {
        case .interruptionBegan:
            pause(reason: .interruption)
        case .oldDeviceUnavailable:
            pause(reason: .oldDeviceUnavailable)
        case .lifecycleBackground:
            pause(reason: .background)
        case .mediaServicesReset:
            let requestID = activeRequestID
            invalidateActiveRequest()
            clearSlots()
            session.deactivate()
            transition(to: .failed, requestID: requestID, error: .mediaServicesReset)
        case .interruptionEnded, .otherRouteChange, .lifecycleInactive, .lifecycleActive:
            break
        }
    }

    private func invalidateActiveRequest() {
        activeRequestID = nil
        currentSlot?.engine.clearCallbacks()
    }

    private func clearSlots() {
        let currentID = currentSlot?.id
        currentSlot?.engine.stop()
        currentSlot?.engine.clearCallbacks()
        if nextSlot?.id != currentID {
            nextSlot?.engine.stop()
            nextSlot?.engine.clearCallbacks()
        }
        currentSlot = nil
        nextSlot = nil
    }

    private func transition(
        to phase: AudioPlaybackPhase,
        requestID: PlaybackRequestID? = nil,
        pauseReason: AudioPauseReason? = nil,
        error: AudioPlayerError? = nil
    ) {
        currentSnapshot = AudioPlaybackSnapshot(
            phase: phase,
            currentURL: currentSlot?.url,
            nextURL: nextSlot?.url,
            requestID: requestID,
            pauseReason: pauseReason,
            error: error
        )
        publish(.stateChanged(currentSnapshot))
    }

    private func publish(_ event: AudioPlayerEvent) {
        for continuation in subscribers.values {
            continuation.yield(event)
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers.removeValue(forKey: id)
    }
}
