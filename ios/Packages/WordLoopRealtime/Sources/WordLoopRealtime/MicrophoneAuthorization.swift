import Foundation

public protocol MicrophoneAuthorizing: Sendable {
    func requestPermission() async -> Bool
}

/// This is invoked only after the user explicitly enters REPEAT. It is not
/// requested at app launch or while browsing/listening.
public struct LiveMicrophoneAuthorizer: MicrophoneAuthorizing, Sendable {
    public init() {}

    public func requestPermission() async -> Bool {
        #if os(iOS)
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        #else
        false
        #endif
    }
}

#if os(iOS)
import AVFoundation
#endif
