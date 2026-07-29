import Foundation
import SwiftData
import XCTest
import WordLoopCore
import WordLoopNetworking
@testable import WordLoopProgress

@MainActor
final class StudySessionRepositoryTests: XCTestCase {
    func testAnonymousIdentityAndRecentCourseSurviveDiskReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "session.store")
        let expected = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

        do {
            let repository = try makeRepository(
                container: WordLoopProgressContainer.makePersistent(storeURL: storeURL),
                uuid: expected
            )
            let activated = try await repository.activate(username: nil)
            XCTAssertEqual(activated.userID, expected.uuidString.lowercased())
            try await repository.saveRecentCourse(userID: activated.userID, courseID: CourseID(rawValue: "course-a")!)
        }

        let reopened = try makeRepository(
            container: WordLoopProgressContainer.makePersistent(storeURL: storeURL),
            uuid: UUID()
        )
        let restored = try await reopened.restore()
        XCTAssertEqual(restored?.userID, expected.uuidString.lowercased())
        XCTAssertEqual(restored?.recentCourseID?.rawValue, "course-a")
        let reused = try await reopened.activate(username: nil)
        XCTAssertEqual(reused.userID, expected.uuidString.lowercased())
    }

    func testNamedIdentityIsNormalizedAndRemoteRecentCourseReplacesLocal() async throws {
        let response = #"{"progress":[],"completions":[],"recentCourseId":"remote-course"}"#
        let repository = try makeRepository(
            container: WordLoopProgressContainer.makeInMemory(),
            uuid: UUID(), response: response
        )
        let named = try await repository.activate(username: " Alice ")
        XCTAssertEqual(named.userID, "name:alice")
        XCTAssertEqual(named.username, "alice")
        try await repository.saveRecentCourse(userID: named.userID, courseID: CourseID(rawValue: "local-course")!)

        let remote = try await repository.syncRecentCourse(userID: named.userID, mode: .repeat)
        XCTAssertEqual(remote?.rawValue, "remote-course")
        let restored = try await repository.restore()
        XCTAssertEqual(restored?.recentCourseID?.rawValue, "remote-course")
    }

    private func makeRepository(
        container: ModelContainer,
        uuid: UUID,
        response: String = #"{"progress":[],"completions":[]}"#
    ) throws -> StudySessionRepository {
        let api = try ProgressAPIClient(
            baseURL: URL(string: "https://boringmax.com/wordloop/api")!,
            transport: ProgressHTTPTransport { request in
                let http = HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (Data(response.utf8), http)
            }
        )
        return StudySessionRepository(container: container, api: api, uuid: { uuid })
    }
}
