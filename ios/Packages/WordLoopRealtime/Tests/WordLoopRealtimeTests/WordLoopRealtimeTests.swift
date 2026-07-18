import XCTest
@testable import WordLoopRealtime

final class WordLoopRealtimeTests: XCTestCase {
    func testModuleIsAvailable() {
        XCTAssertEqual(WordLoopRealtimeModule.name, "WordLoopRealtime")
    }

    func testSessionClientPostsSDPToVPSContract() async throws {
        let transport = RealtimeHTTPTransport { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.com/wordloop/api/pronunciation-session")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/sdp")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-user-id"), "name:alex")
            XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), "offer-sdp")
            return (Data("answer-sdp".utf8), HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/sdp"]
            )!)
        }
        let client = try PronunciationSessionClient(
            baseURL: URL(string: "https://example.com/wordloop/api")!,
            transport: transport
        )

        let answer = try await client.createSession(offerSDP: "offer-sdp", userID: "name:alex")

        XCTAssertEqual(answer, "answer-sdp")
    }

    func testSessionClientRejectsEmptyAnswer() async throws {
        let transport = RealtimeHTTPTransport { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = try PronunciationSessionClient(baseURL: URL(string: "https://example.com/api")!, transport: transport)

        await XCTAssertThrowsErrorAsync(try await client.createSession(offerSDP: "offer")) { error in
            XCTAssertEqual(error as? RealtimeTransportError, .invalidSDPAnswer)
        }
    }

    func testDecoderKeepsLifecycleItemIDsAndIgnoresUnknownEvents() {
        XCTAssertEqual(
            RealtimeEventDecoder.decode(Data(#"{"type":"input_audio_buffer.speech_started","item_id":"item-7"}"#.utf8)),
            .speechStarted(itemID: "item-7")
        )
        XCTAssertEqual(
            RealtimeEventDecoder.decode(Data(#"{"type":"conversation.item.input_audio_transcription.completed","item_id":"item-7","transcript":"hello world"}"#.utf8)),
            .transcriptionCompleted(itemID: "item-7", transcript: "hello world")
        )
        XCTAssertNil(RealtimeEventDecoder.decode(Data(#"{"type":"rate_limits.updated"}"#.utf8)))
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw")
    } catch {
        errorHandler(error)
    }
}
