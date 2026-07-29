import Foundation

public enum RealtimeTransportError: Error, Equatable, Sendable {
    case invalidBaseURL
    case nonHTTPResponse
    case rejected(statusCode: Int, message: String?)
    case invalidSDPAnswer
    case unavailablePeerConnection
}

public struct RealtimeHTTPTransport: @unchecked Sendable {
    public var data: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    public init(data: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) {
        self.data = data
    }

    public static let live = RealtimeHTTPTransport { request in
        try await URLSession.shared.data(for: request)
    }
}

/// The only app-to-server request used to create a pronunciation session.
/// The VPS owns the OpenAI credential and returns the WebRTC SDP answer.
public struct PronunciationSessionClient: Sendable {
    private let endpoint: URL
    private let transport: RealtimeHTTPTransport

    public init(baseURL: URL, transport: RealtimeHTTPTransport = .live) throws {
        guard baseURL.scheme?.lowercased() == "https",
              baseURL.host != nil,
              let endpoint = URL(
                string: "pronunciation-session",
                relativeTo: baseURL.appendingPathComponent("/")
              )?.absoluteURL else {
            throw RealtimeTransportError.invalidBaseURL
        }
        self.endpoint = endpoint
        self.transport = transport
    }

    public func createSession(offerSDP: String, userID: String? = nil) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        if let userID, !userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue(userID, forHTTPHeaderField: "x-user-id")
        }
        request.httpBody = Data(offerSDP.utf8)

        let (data, rawResponse) = try await transport.data(request)
        guard let response = rawResponse as? HTTPURLResponse else {
            throw RealtimeTransportError.nonHTTPResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw RealtimeTransportError.rejected(
                statusCode: response.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
        guard let answer = String(data: data, encoding: .utf8), !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RealtimeTransportError.invalidSDPAnswer
        }
        return answer
    }
}

public enum RealtimeTransportEvent: Equatable, Sendable {
    case speechStarted(itemID: String)
    case speechStopped(itemID: String?)
    case audioCommitted(itemID: String?)
    case transcriptionCompleted(itemID: String, transcript: String)
    case transcriptionFailed(itemID: String?)
}

/// Decodes only lifecycle messages needed by the repeat state machine. Unknown
/// provider events deliberately stay inside the transport boundary.
public enum RealtimeEventDecoder {
    public static func decode(_ data: Data) -> RealtimeTransportEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else { return nil }
        let itemID = object["item_id"] as? String
        switch type {
        case "input_audio_buffer.speech_started":
            guard let itemID, !itemID.isEmpty else { return nil }
            return .speechStarted(itemID: itemID)
        case "input_audio_buffer.speech_stopped":
            return .speechStopped(itemID: itemID)
        case "input_audio_buffer.committed":
            return .audioCommitted(itemID: itemID)
        case "conversation.item.input_audio_transcription.completed":
            guard let itemID, !itemID.isEmpty,
                  let transcript = object["transcript"] as? String else { return nil }
            return .transcriptionCompleted(itemID: itemID, transcript: transcript)
        case "conversation.item.input_audio_transcription.failed":
            return .transcriptionFailed(itemID: itemID)
        default:
            return nil
        }
    }
}
