import Foundation
import XCTest
@testable import WordLoopNetworking

final class ProgressAPIClientTests: XCTestCase {
    func testCourseGETUsesInjectedVPSBaseAndExactQuery() async throws {
        let recorder = RequestRecorder(response: .json(#"{"progress":[{"itemId":"line-001","studyCount":2}]}"#))
        let client = try makeClient(recorder)

        let response = try await client.fetchCourseProgress(.init(
            userID: "name:alice", mode: .listen, courseID: "course-a"
        ))

        XCTAssertEqual(response.progress, [.init(itemId: "line-001", studyCount: 2)])
        let captured = await recorder.requests()
        let request = try XCTUnwrap(captured.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://boringmax.com/wordloop/api/progress?userId=name:alice&mode=listen&courseId=course-a")
    }

    func testCoursePOSTUsesExactDTOAndOriginalEventID() async throws {
        let recorder = RequestRecorder(response: .json(#"{"itemId":"line-001","studyCount":3}"#))
        let client = try makeClient(recorder)

        let response = try await client.sendCourseProgress(.init(
            userId: "name:alice", mode: .repeat, clientEventId: "event-001",
            courseId: "course-a", itemId: "line-001", markMastered: true
        ))

        XCTAssertEqual(response, .init(itemId: "line-001", studyCount: 3))
        let captured = await recorder.requests()
        let request = try XCTUnwrap(captured.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: AnyHashable])
        XCTAssertEqual(object["clientEventId"], "event-001")
        XCTAssertEqual(object["markMastered"], true)
        XCTAssertEqual(object["courseId"], "course-a")
    }

    func testOverviewAndSelectCourseUseVPSContractShapes() async throws {
        let overviewRecorder = RequestRecorder(response: .json(
            #"{"progress":[],"completions":[],"recentCourseId":"course-a"}"#
        ))
        let overview = try await makeClient(overviewRecorder).fetchProgressOverview(
            userID: "name:alice", mode: .repeat
        )
        XCTAssertEqual(overview.recentCourseId, "course-a")
        let overviewRequests = await overviewRecorder.requests()
        let get = try XCTUnwrap(overviewRequests.first)
        XCTAssertEqual(get.url?.absoluteString, "https://boringmax.com/wordloop/api/progress?userId=name:alice&mode=repeat")

        let selectRecorder = RequestRecorder(response: .json(#"{"recentCourseId":"course-b"}"#))
        let selected = try await makeClient(selectRecorder).selectCourse(.init(
            userId: "name:alice", mode: .listen, courseId: "course-b"
        ))
        XCTAssertEqual(selected.recentCourseId, "course-b")
        let selectRequests = await selectRecorder.requests()
        let post = try XCTUnwrap(selectRequests.first)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(post.httpBody)) as? [String: AnyHashable])
        XCTAssertEqual(object["selectCourse"], true)
        XCTAssertEqual(object["courseId"], "course-b")
    }

    func testHTTPAndDecodeFailuresRemainStructured() async throws {
        let rejected = RequestRecorder(response: .init(
            data: Data(#"{"error":"invalid progress update"}"#.utf8),
            statusCode: 400
        ))
        let rejectedClient = try makeClient(rejected)
        await assertThrows(
            .rejected(statusCode: 400, message: "invalid progress update")
        ) {
            _ = try await rejectedClient.fetchCourseProgress(.init(
                userID: "name:alice", mode: .listen, courseID: "course-a"
            ))
        }

        let invalid = RequestRecorder(response: .json("not-json"))
        let invalidClient = try makeClient(invalid)
        await assertThrows(.invalidResponse) {
            _ = try await invalidClient.fetchCourseProgress(.init(
                userID: "name:alice", mode: .listen, courseID: "course-a"
            ))
        }
    }

    func testClientRejectsNonHTTPSBase() {
        XCTAssertThrowsError(try ProgressAPIClient(baseURL: URL(string: "http://boringmax.com/wordloop/api")!)) { error in
            XCTAssertEqual(error as? ProgressAPIError, .invalidBaseURL)
        }
    }

    private func makeClient(_ recorder: RequestRecorder) throws -> ProgressAPIClient {
        try ProgressAPIClient(
            baseURL: URL(string: "https://boringmax.com/wordloop/api")!,
            transport: ProgressHTTPTransport { request in try await recorder.respond(to: request) }
        )
    }

    private func assertThrows(
        _ expected: ProgressAPIError,
        operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected operation to throw", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? ProgressAPIError, expected, file: file, line: line)
        }
    }
}

private actor RequestRecorder {
    struct Stub: Sendable {
        let data: Data
        let statusCode: Int

        static func json(_ string: String) -> Stub {
            Stub(data: Data(string.utf8), statusCode: 200)
        }
    }

    private var captured: [URLRequest] = []
    private let response: Stub

    init(response: Stub) { self.response = response }

    func respond(to request: URLRequest) throws -> (Data, URLResponse) {
        captured.append(request)
        let response = try XCTUnwrap(HTTPURLResponse(
            url: request.url!, statusCode: self.response.statusCode,
            httpVersion: nil, headerFields: ["Content-Type": "application/json"]
        ))
        return (self.response.data, response)
    }

    func requests() -> [URLRequest] { captured }
}
