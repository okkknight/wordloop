import Foundation
import SwiftData
import XCTest
import WordLoopCore
import WordLoopNetworking
@testable import WordLoopProgress

@MainActor
final class CompletionResetRepositoryTests: XCTestCase {
    func testResetIsPersistedOrderedAndOnlyClearsRequestedModeCourse() async throws {
        let container = try WordLoopProgressContainer.makeInMemory()
        let context = container.mainContext
        context.insert(record(mode: .listen, count: 2))
        context.insert(record(mode: .repeat, count: 3))
        try context.save()
        let transport = CompletionResetTransport(results: [.reset, .progress(1)])
        let repository = try makeRepository(container: container, transport: transport, ids: ["reset-001", "learn-002"])

        try await repository.reset(userID: user, mode: .listen, courseID: course)
        _ = try await repository.record(userID: user, mode: .listen, courseID: course, entryID: entry)
        let listen = try await repository.snapshot(userID: user, mode: .listen, courseID: course)
        let repeated = try await repository.snapshot(userID: user, mode: .repeat, courseID: course)
        XCTAssertEqual(listen, [entry: 1])
        XCTAssertEqual(repeated, [entry: 3])

        let result = try await repository.flush(userID: user, mode: .listen, trigger: .manualRetry)
        XCTAssertEqual(result, .completed(sent: 2))
        let bodies = await transport.bodies()
        XCTAssertNotNil(bodies.first?["resetCourse"])
        XCTAssertEqual(bodies.last?["clientEventId"], "learn-002")
    }

    func testCompletionPersistsProjectsAndRetriesOriginalClientEventID() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "completion.store")
        let transport = CompletionResetTransport(results: [.failure, .completion(1)])

        do {
            let repository = try makeRepository(
                container: WordLoopProgressContainer.makePersistent(storeURL: storeURL),
                transport: transport, ids: []
            )
            let projected = try await repository.complete(
                userID: user, courseID: course, clientEventID: "completion-001"
            )
            XCTAssertEqual(projected, 1)
            do {
                _ = try await repository.flush(userID: user, mode: .repeat, trigger: .networkRecovered)
                XCTFail("Expected failure")
            } catch {}
        }

        let reopened = try makeRepository(
            container: WordLoopProgressContainer.makePersistent(storeURL: storeURL),
            transport: transport, ids: []
        )
        let pending = try await reopened.completions(userID: user)
        XCTAssertEqual(pending[course], 1)
        let flushed = try await reopened.flush(userID: user, mode: .repeat, trigger: .manualRetry)
        XCTAssertEqual(flushed, .completed(sent: 1))
        let confirmed = try await reopened.completions(userID: user)
        XCTAssertEqual(confirmed[course], 1)
        let bodies = await transport.bodies()
        XCTAssertEqual(bodies.compactMap { $0["clientEventId"] }, ["completion-001", "completion-001"])
    }

    private let user = "name:alice"
    private var course: CourseID { CourseID(rawValue: "course-a")! }
    private var entry: EntryID { EntryID(rawValue: "line-001")! }

    private func record(mode: StudyMode, count: Int) -> ProgressRecord {
        ProgressRecord(
            userID: user, modeRawValue: mode.rawValue, courseID: course.rawValue,
            entryID: entry.rawValue, studyCount: count, updatedAt: Date()
        )
    }

    private func makeRepository(
        container: ModelContainer,
        transport: CompletionResetTransport,
        ids: [String]
    ) throws -> PersistentProgressRepository {
        let values = LockedCompletionIDs(ids)
        let api = try ProgressAPIClient(
            baseURL: URL(string: "https://boringmax.com/wordloop/api")!,
            transport: .init { request in try await transport.respond(request) }
        )
        return PersistentProgressRepository(container: container, api: api, eventID: { values.next() })
    }
}

private final class LockedCompletionIDs: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String]
    init(_ values: [String]) { self.values = values }
    func next() -> String { lock.withLock { values.removeFirst() } }
}

private actor CompletionResetTransport {
    enum Result: Sendable { case reset, completion(Int), failure, progress(Int) }
    enum Failure: Error { case offline }
    private var results: [Result]
    private var captured: [[String: String]] = []

    init(results: [Result]) { self.results = results }

    func respond(_ request: URLRequest) throws -> (Data, URLResponse) {
        let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any] ?? [:]
        captured.append(body.reduce(into: [:]) { result, item in result[item.key] = String(describing: item.value) })
        guard !results.isEmpty else { throw Failure.offline }
        let result = results.removeFirst()
        let json: String
        switch result {
        case .reset: json = #"{"courseId":"course-a","reset":true}"#
        case let .completion(count): json = #"{"courseId":"course-a","completionCount":\#(count)}"#
        case let .progress(count): json = #"{"itemId":"line-001","studyCount":\#(count)}"#
        case .failure: throw Failure.offline
        }
        return (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }

    func bodies() -> [[String: String]] { captured }
}
