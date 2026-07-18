import XCTest
@testable import WordLoopNetworking

final class WordLoopNetworkingTests: XCTestCase {
    func testModuleIsAvailable() {
        XCTAssertEqual(WordLoopNetworkingModule.name, "WordLoopNetworking")
    }

    func testSharedGetFixturesDecodeExactWireShapes() throws {
        let word = try decode(WordProgressSnapshotDTO.self, fixture: "get-word-success.json")
        XCTAssertEqual(word.progress, [.init(word: "example", studyCount: 2)])
        XCTAssertEqual(word.completions, [.init(courseId: "course-a", completionCount: 1)])
        XCTAssertEqual(word.recentCourseId, "course-a")

        let course = try decode(CourseProgressSnapshotDTO.self, fixture: "get-course-success.json")
        XCTAssertEqual(course.progress, [.init(itemId: "line-001", studyCount: 3)])

        let missingRecent = try JSONDecoder().decode(
            WordProgressSnapshotDTO.self,
            from: Data(#"{"progress":[],"completions":[]}"#.utf8)
        )
        XCTAssertNil(missingRecent.recentCourseId)
    }

    func testExplicitPostDTOsMatchEverySharedFixture() throws {
        let cases = try postCases()
        let requests: [String: any Encodable] = [
            "word-progress": WordProgressRequestDTO(
                userId: "name:alice", mode: .listen, clientEventId: "event-001", word: "example"
            ),
            "course-progress-mastered": CourseProgressRequestDTO(
                userId: "name:alice", mode: .repeat, clientEventId: "event-002",
                courseId: "course-a", itemId: "line-001", markMastered: true
            ),
            "select-course": SelectCourseRequestDTO(userId: "name:alice", mode: .listen, courseId: "course-a"),
            "reset-course": ResetCourseRequestDTO(userId: "name:alice", mode: .repeat, courseId: "course-a"),
            "complete-course": CompleteCourseRequestDTO(
                userId: "name:alice", mode: .listen, clientEventId: "event-003", courseId: "course-a"
            ),
        ]

        XCTAssertEqual(Set(cases.map(\.name)), Set(requests.keys))
        for fixture in cases {
            let request = try XCTUnwrap(requests[fixture.name])
            XCTAssertEqual(try jsonObject(JSONEncoder().encode(request)), fixture.request)
        }
    }

    func testNormalRequestsOmitFalseMarkMasteredAndQueryUsesWireNames() throws {
        let word = WordProgressRequestDTO(
            userId: "name:alice", mode: .listen, clientEventId: "event-004", word: "example"
        )
        guard case let .object(object) = try jsonObject(JSONEncoder().encode(word)) else {
            return XCTFail("Expected a JSON object")
        }
        XCTAssertNil(object["markMastered"])

        let query = ProgressQueryDTO(userID: "name:alice", mode: .repeat, courseID: "course-a")
        XCTAssertEqual(query.queryItems.map(\.name), ["userId", "mode", "courseId"])
        XCTAssertEqual(query.queryItems.map(\.value), ["name:alice", "repeat", "course-a"])
    }

    private struct PostCase: Decodable {
        let name: String
        let request: AnyJSON
    }

    private enum AnyJSON: Decodable, Equatable {
        case string(String), number(Int), bool(Bool), object([String: AnyJSON]), array([AnyJSON]), null

        init(from decoder: any Decoder) throws {
            let value = try decoder.singleValueContainer()
            if value.decodeNil() { self = .null }
            else if let decoded = try? value.decode(Bool.self) { self = .bool(decoded) }
            else if let decoded = try? value.decode(Int.self) { self = .number(decoded) }
            else if let decoded = try? value.decode(String.self) { self = .string(decoded) }
            else if let decoded = try? value.decode([String: AnyJSON].self) { self = .object(decoded) }
            else { self = .array(try value.decode([AnyJSON].self)) }
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, fixture: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: fixtureURL(fixture)))
    }

    private func postCases() throws -> [PostCase] {
        try JSONDecoder().decode([PostCase].self, from: Data(contentsOf: fixtureURL("post-cases.json")))
    }

    private func fixtureURL(_ name: String) -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        return root.appending(path: "contracts/progress/\(name)")
    }

    private func jsonObject(_ data: Data) throws -> AnyJSON {
        try JSONDecoder().decode(AnyJSON.self, from: data)
    }
}
