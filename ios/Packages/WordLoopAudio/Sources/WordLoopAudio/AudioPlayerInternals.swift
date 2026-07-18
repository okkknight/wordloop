import Foundation

protocol AudioEngine: AnyObject {
    var id: UUID { get }
    var url: URL { get }
    var currentTime: TimeInterval { get set }

    func prepareToPlay() -> Bool
    func play() -> Bool
    func pause()
    func stop()
    func installCallbacks(
        onFinish: @escaping @Sendable () async -> Void,
        onDecodeFailure: @escaping @Sendable () async -> Void
    )
    func clearCallbacks()
}

protocol AudioEngineFactory: Sendable {
    func makeEngine(url: URL) throws -> any AudioEngine
}

protocol AudioSessionControlling: Sendable {
    func configureForSpokenPlayback() throws
    func configureForRepeat() throws
    func activate() throws
    func deactivate()
}

enum AudioSystemEvent: Equatable, Sendable {
    case interruptionBegan
    case interruptionEnded
    case oldDeviceUnavailable
    case otherRouteChange
    case lifecycleBackground
    case lifecycleInactive
    case lifecycleActive
    case mediaServicesReset
}

protocol AudioSystemEventSource: Sendable {
    func setHandler(_ handler: (@Sendable (AudioSystemEvent) async -> Void)?)
}

struct AudioEngineSlot {
    let engine: any AudioEngine

    var id: UUID { engine.id }
    var url: URL { engine.url }
}

struct PlaybackRequestIDGenerator: Sendable {
    private let generateValue: @Sendable () -> UUID

    init(generateValue: @escaping @Sendable () -> UUID = UUID.init) {
        self.generateValue = generateValue
    }

    func next() -> PlaybackRequestID {
        PlaybackRequestID(rawValue: generateValue())
    }
}
