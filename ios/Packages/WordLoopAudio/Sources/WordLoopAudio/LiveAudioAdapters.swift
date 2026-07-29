import AVFoundation
import Foundation

private final class AudioEngineCallbacks: @unchecked Sendable {
    private let lock = NSLock()
    private var finish: (@Sendable () async -> Void)?
    private var decodeFailure: (@Sendable () async -> Void)?

    func install(
        finish: @escaping @Sendable () async -> Void,
        decodeFailure: @escaping @Sendable () async -> Void
    ) {
        lock.withLock {
            self.finish = finish
            self.decodeFailure = decodeFailure
        }
    }

    func clear() {
        lock.withLock {
            finish = nil
            decodeFailure = nil
        }
    }

    func fireFinish() {
        let callback = lock.withLock { finish }
        guard let callback else { return }
        Task { await callback() }
    }

    func fireDecodeFailure() {
        let callback = lock.withLock { decodeFailure }
        guard let callback else { return }
        Task { await callback() }
    }
}

private final class LocalAVAudioPlayerEngine: NSObject, AudioEngine, AVAudioPlayerDelegate {
    let id = UUID()
    let url: URL
    private let player: AVAudioPlayer
    private let callbacks = AudioEngineCallbacks()

    init(url: URL) throws {
        self.url = url
        player = try AVAudioPlayer(contentsOf: url)
        super.init()
        player.delegate = self
    }

    var currentTime: TimeInterval {
        get { player.currentTime }
        set { player.currentTime = newValue }
    }

    func prepareToPlay() -> Bool { player.prepareToPlay() }
    func play() -> Bool { player.play() }
    func pause() { player.pause() }
    func stop() { player.stop() }

    func installCallbacks(
        onFinish: @escaping @Sendable () async -> Void,
        onDecodeFailure: @escaping @Sendable () async -> Void
    ) {
        callbacks.install(finish: onFinish, decodeFailure: onDecodeFailure)
    }

    func clearCallbacks() {
        callbacks.clear()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            callbacks.fireFinish()
        } else {
            callbacks.fireDecodeFailure()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        callbacks.fireDecodeFailure()
    }
}

struct AVAudioEngineFactory: AudioEngineFactory {
    func makeEngine(url: URL) throws -> any AudioEngine {
        try LocalAVAudioPlayerEngine(url: url)
    }
}

#if os(iOS)
import UIKit

struct IOSAudioSessionController: AudioSessionControlling, @unchecked Sendable {
    private let session = AVAudioSession.sharedInstance()

    func configureForSpokenPlayback() throws {
        try session.setCategory(.playback, mode: .spokenAudio, options: [])
    }

    func configureForRepeat() throws {
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
    }

    func activate() throws {
        try session.setActive(true)
    }

    func deactivate() {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
}

final class IOSAudioSystemEventSource: AudioSystemEventSource, @unchecked Sendable {
    private let lock = NSLock()
    private let notificationCenter: NotificationCenter
    private var handler: (@Sendable (AudioSystemEvent) async -> Void)?
    private var observerTokens: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        observerTokens = [
            notificationCenter.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                self?.send(type == .began ? .interruptionBegan : .interruptionEnded)
            },
            notificationCenter.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
                self?.send(reason == .oldDeviceUnavailable ? .oldDeviceUnavailable : .otherRouteChange)
            },
            notificationCenter.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in self?.send(.mediaServicesReset) },
            notificationCenter.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in self?.send(.lifecycleBackground) },
            notificationCenter.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in self?.send(.lifecycleInactive) },
            notificationCenter.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in self?.send(.lifecycleActive) },
        ]
    }

    deinit {
        for token in observerTokens {
            notificationCenter.removeObserver(token)
        }
    }

    func setHandler(_ handler: (@Sendable (AudioSystemEvent) async -> Void)?) {
        lock.withLock { self.handler = handler }
    }

    private func send(_ event: AudioSystemEvent) {
        let callback: (@Sendable (AudioSystemEvent) async -> Void)? = lock.withLock { self.handler }
        guard let callback else { return }
        Task { await callback(event) }
    }
}
#endif
