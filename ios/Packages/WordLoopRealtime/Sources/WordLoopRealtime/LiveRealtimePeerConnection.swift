import Foundation
import WebRTC

public enum RealtimePeerConnectionState: Equatable, Sendable {
    case connecting
    case ready
    case disconnected
    case failed
}

/// A narrow WebRTC adapter. It owns SDP/DataChannel/media details and emits
/// decoded events only; the repeat controller owns turns, scoring and UI.
public final class LiveRealtimePeerConnection: NSObject, @unchecked Sendable {
    public var onEvent: (@Sendable (RealtimeTransportEvent) -> Void)?
    public var onStateChange: (@Sendable (RealtimePeerConnectionState) -> Void)?

    private let sessionClient: PronunciationSessionClient
    private let factory = RTCPeerConnectionFactory()
    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    private var audioTrack: RTCAudioTrack?
    private var audioSource: RTCAudioSource?

    public init(sessionClient: PronunciationSessionClient) {
        self.sessionClient = sessionClient
    }

    public func connect(userID: String?) async throws {
        close()
        onStateChange?(.connecting)

        let configuration = RTCConfiguration()
        configuration.sdpSemantics = .unifiedPlan
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "false"],
            optionalConstraints: nil
        )
        guard let peerConnection = factory.peerConnection(
            with: configuration,
            constraints: constraints,
            delegate: self
        ) else {
            onStateChange?(.failed)
            throw RealtimeTransportError.unavailablePeerConnection
        }
        let channel = peerConnection.dataChannel(
            forLabel: "oai-events",
            configuration: RTCDataChannelConfiguration()
        )
        channel?.delegate = self

        let source = factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        let track = factory.audioTrack(with: source, trackId: "wordloop-microphone")
        track.isEnabled = false
        _ = peerConnection.add(track, streamIds: ["wordloop"])

        self.peerConnection = peerConnection
        dataChannel = channel
        audioSource = source
        audioTrack = track

        do {
            let offerSDP = try await makeOfferSDP(peerConnection, constraints: constraints)
            let offer = RTCSessionDescription(type: .offer, sdp: offerSDP)
            try await setLocalDescription(offer, on: peerConnection)
            let answerSDP = try await sessionClient.createSession(offerSDP: offerSDP, userID: userID)
            try await setRemoteDescription(
                RTCSessionDescription(type: .answer, sdp: answerSDP),
                on: peerConnection
            )
        } catch {
            close()
            onStateChange?(.failed)
            throw error
        }
    }

    public func setMicrophoneEnabled(_ enabled: Bool) {
        audioTrack?.isEnabled = enabled
    }

    public func close() {
        dataChannel?.delegate = nil
        dataChannel?.close()
        dataChannel = nil
        peerConnection?.close()
        peerConnection = nil
        audioTrack = nil
        audioSource = nil
    }

    private func makeOfferSDP(
        _ peerConnection: RTCPeerConnection,
        constraints: RTCMediaConstraints
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            peerConnection.offer(for: constraints) { description, error in
                if let description {
                    continuation.resume(returning: description.sdp)
                } else {
                    continuation.resume(throwing: error ?? RealtimeTransportError.invalidSDPAnswer)
                }
            }
        }
    }

    private func setLocalDescription(
        _ description: RTCSessionDescription,
        on peerConnection: RTCPeerConnection
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peerConnection.setLocalDescription(description) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }

    private func setRemoteDescription(
        _ description: RTCSessionDescription,
        on peerConnection: RTCPeerConnection
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peerConnection.setRemoteDescription(description) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }
}

extension LiveRealtimePeerConnection: RTCDataChannelDelegate {
    public func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        if dataChannel.readyState == .open {
            onStateChange?(.ready)
        }
    }

    public func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        guard !buffer.isBinary, let event = RealtimeEventDecoder.decode(buffer.data) else { return }
        onEvent?(event)
    }
}

extension LiveRealtimePeerConnection: RTCPeerConnectionDelegate {
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {}
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}

    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        switch newState {
        case .failed: onStateChange?(.failed)
        case .disconnected, .closed: onStateChange?(.disconnected)
        default: break
        }
    }
}
