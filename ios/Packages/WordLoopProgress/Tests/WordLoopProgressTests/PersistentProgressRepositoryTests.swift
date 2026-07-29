import Foundation
import SwiftData
import XCTest
import WordLoopCore
import WordLoopNetworking
@testable import WordLoopProgress

@MainActor
final class PersistentProgressRepositoryTests: XCTestCase {
    func testOfflineEventsPersistBeforeProjectionAndSurviveReopen() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "progress.store")
        let ids = LockedValues(["event-001", "event-002"])

        do {
            let container = try WordLoopProgressContainer.makePersistent(storeURL: storeURL)
            let repository = try makeRepository(container: container, stub: .offline(), ids: ids)
            let recorded = try await repository.record(userID: "name:alice", mode: .listen, courseID: course, entryID: entry)
            let mastered = try await repository.master(userID: "name:alice", mode: .listen, courseID: course, entryID: entry)
            XCTAssertEqual(recorded, 1)
            XCTAssertEqual(mastered, 3)

            let context = container.mainContext
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProgressRecord>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProgressEvent>()), 2)
        }

        let reopened = try WordLoopProgressContainer.makePersistent(storeURL: storeURL)
        let repository = try makeRepository(container: reopened, stub: .offline(), ids: ids)
        let restored = try await repository.snapshot(userID: "name:alice", mode: .listen, courseID: course)
        XCTAssertEqual(restored, [entry: 3])
    }

    func testProjectionMergesConfirmedAndPendingWithStrictPartitionsAndClamp() async throws {
        let container = try WordLoopProgressContainer.makeInMemory()
        let context = container.mainContext
        context.insert(ProgressRecord(
            userID: "name:alice", modeRawValue: "listen", courseID: course.rawValue,
            entryID: entry.rawValue, studyCount: 2, updatedAt: fixedDate
        ))
        try context.save()
        let ids = LockedValues(["event-001", "event-002", "event-003"])
        let repository = try makeRepository(container: container, stub: .offline(), ids: ids)

        let first = try await repository.record(userID: "name:alice", mode: .listen, courseID: course, entryID: entry)
        let second = try await repository.record(userID: "name:alice", mode: .listen, courseID: course, entryID: entry)
        let repeatValue = try await repository.record(userID: "name:alice", mode: .repeat, courseID: course, entryID: entry)
        XCTAssertEqual(first, 3)
        XCTAssertEqual(second, 3)
        XCTAssertEqual(repeatValue, 1)

        let listen = try await repository.snapshot(userID: "name:alice", mode: .listen, courseID: course)
        let repeated = try await repository.snapshot(userID: "name:alice", mode: .repeat, courseID: course)
        let otherUser = try await repository.snapshot(userID: "name:bob", mode: .listen, courseID: course)
        XCTAssertEqual(listen, [entry: 3])
        XCTAssertEqual(repeated, [entry: 1])
        XCTAssertEqual(otherUser, [:])
    }

    func testFailureStopsPartitionAndRetryReusesEventIDsInOrder() async throws {
        let container = try WordLoopProgressContainer.makeInMemory()
        let stub = ProgressTransportStub(results: [
            .failure(.offline),
            .success(1),
            .success(2),
        ])
        let ids = LockedValues(["event-001", "event-002"])
        let repository = try makeRepository(container: container, stub: stub, ids: ids)
        _ = try await repository.record(userID: "name:alice", mode: .listen, courseID: course, entryID: entry)
        _ = try await repository.record(userID: "name:alice", mode: .listen, courseID: course, entryID: entry)

        do {
            _ = try await repository.flush(userID: "name:alice", mode: .listen, trigger: .networkRecovered)
            XCTFail("Expected offline failure")
        } catch {
            XCTAssertEqual(error as? StubError, .offline)
        }
        let firstIDs = await stub.eventIDs()
        let offlineSnapshot = try await repository.snapshot(userID: "name:alice", mode: .listen, courseID: course)
        XCTAssertEqual(firstIDs, ["event-001"])
        XCTAssertEqual(offlineSnapshot, [entry: 2])
        let failedEvent = try XCTUnwrap(container.mainContext.fetch(
            FetchDescriptor<ProgressEvent>(sortBy: [SortDescriptor(\ProgressEvent.clientEventID)])
        ).first)
        XCTAssertEqual(failedEvent.stateRawValue, ProgressOutboxState.pending.rawValue)
        XCTAssertEqual(failedEvent.attemptCount, 1)
        XCTAssertEqual(failedEvent.lastAttemptAt, fixedDate)

        let retry = try await repository.flush(userID: "name:alice", mode: .listen, trigger: .manualRetry)
        let retriedIDs = await stub.eventIDs()
        let syncedSnapshot = try await repository.snapshot(userID: "name:alice", mode: .listen, courseID: course)
        XCTAssertEqual(retry, .completed(sent: 2))
        XCTAssertEqual(retriedIDs, ["event-001", "event-001", "event-002"])
        XCTAssertEqual(syncedSnapshot, [entry: 2])
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<ProgressEvent>()), 0)
        let record = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<ProgressRecord>()).first)
        XCTAssertEqual(record.studyCount, 2)
    }

    func testConcurrentTriggersCoalesceWhileOnePartitionIsInFlight() async throws {
        let container = try WordLoopProgressContainer.makeInMemory()
        let stub = ProgressTransportStub(results: [.success(1)], suspendsFirstRequest: true)
        let repository = try makeRepository(
            container: container,
            stub: stub,
            ids: LockedValues(["event-001"])
        )
        _ = try await repository.record(userID: "name:alice", mode: .listen, courseID: course, entryID: entry)

        let first = Task {
            try await repository.flush(userID: "name:alice", mode: .listen, trigger: .appBecameActive)
        }
        await stub.waitUntilSuspended()
        let second = try await repository.flush(userID: "name:alice", mode: .listen, trigger: .manualRetry)
        XCTAssertEqual(second, .coalesced)
        await stub.release()
        let firstResult = try await first.value
        let ids = await stub.eventIDs()
        XCTAssertEqual(firstResult, .completed(sent: 1))
        XCTAssertEqual(ids, ["event-001"])
    }

    func testRefreshReplacesOnlyConfirmedCourseAndKeepsPendingProjection() async throws {
        let container = try WordLoopProgressContainer.makeInMemory()
        let context = container.mainContext
        context.insert(ProgressRecord(userID: "name:alice", modeRawValue: "listen", courseID: course.rawValue, entryID: entry.rawValue, studyCount: 3, updatedAt: fixedDate))
        context.insert(ProgressRecord(userID: "name:alice", modeRawValue: "repeat", courseID: course.rawValue, entryID: entry.rawValue, studyCount: 2, updatedAt: fixedDate))
        try context.save()
        let stub = ProgressTransportStub(results: [.snapshot([.init(itemId: entry.rawValue, studyCount: 1)])])
        let repository = try makeRepository(container: container, stub: stub, ids: LockedValues(["event-001"]))
        _ = try await repository.record(userID: "name:alice", mode: .listen, courseID: course, entryID: entry)

        let refreshed = try await repository.refresh(userID: "name:alice", mode: .listen, courseID: course)
        let repeated = try await repository.snapshot(userID: "name:alice", mode: .repeat, courseID: course)
        XCTAssertEqual(refreshed, [entry: 2])
        XCTAssertEqual(repeated, [entry: 2])
    }

    func testInterruptedSendingRecoversAndUnknownRawValuesFailClosed() async throws {
        let container = try WordLoopProgressContainer.makeInMemory()
        let context = container.mainContext
        context.insert(ProgressEvent(
            clientEventID: "event-001", userID: "name:alice", modeRawValue: "listen",
            courseID: course.rawValue, entryID: entry.rawValue,
            kindRawValue: "increment", stateRawValue: "sending", createdAt: fixedDate
        ))
        try context.save()
        let repository = try makeRepository(container: container, stub: .offline(), ids: LockedValues([]))
        let recovered = try await repository.snapshot(userID: "name:alice", mode: .listen, courseID: course)
        XCTAssertEqual(recovered, [entry: 1])
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProgressEvent>()).first?.stateRawValue, "pending")

        context.insert(ProgressEvent(
            clientEventID: "event-unknown", userID: "name:alice", modeRawValue: "listen",
            courseID: course.rawValue, entryID: entry.rawValue,
            kindRawValue: "mystery", stateRawValue: "pending", createdAt: fixedDate.addingTimeInterval(1)
        ))
        try context.save()
        do {
            _ = try await repository.snapshot(userID: "name:alice", mode: .listen, courseID: course)
            XCTFail("Expected invalid raw value")
        } catch {
            XCTAssertEqual(error as? PersistentProgressError, .invalidEventKind("mystery"))
        }
    }

    private var course: CourseID { CourseID(rawValue: "course-a")! }
    private var entry: EntryID { EntryID(rawValue: "line-001")! }
    private var fixedDate: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    private func makeRepository(
        container: ModelContainer,
        stub: ProgressTransportStub,
        ids: LockedValues
    ) throws -> PersistentProgressRepository {
        let client = try ProgressAPIClient(
            baseURL: URL(string: "https://boringmax.com/wordloop/api")!,
            transport: ProgressHTTPTransport { request in try await stub.respond(to: request) }
        )
        return PersistentProgressRepository(
            container: container,
            api: client,
            eventID: { ids.next() },
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "wordloop-outbox-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private enum StubError: Error, Equatable, Sendable { case offline, exhausted }

private actor ProgressTransportStub {
    enum Result: Sendable {
        case success(Int)
        case snapshot([CourseItemProgressDTO])
        case failure(StubError)
    }

    private var results: [Result]
    private var capturedEventIDs: [String] = []
    private var suspendsFirstRequest: Bool
    private var suspended = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var observers: [CheckedContinuation<Void, Never>] = []

    init(results: [Result], suspendsFirstRequest: Bool = false) {
        self.results = results
        self.suspendsFirstRequest = suspendsFirstRequest
    }

    static func offline() -> ProgressTransportStub {
        ProgressTransportStub(results: [.failure(.offline)])
    }

    func respond(to request: URLRequest) async throws -> (Data, URLResponse) {
        let body = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        if let id = body?["clientEventId"] as? String { capturedEventIDs.append(id) }
        if suspendsFirstRequest {
            suspendsFirstRequest = false
            suspended = true
            let waiting = observers
            observers.removeAll()
            waiting.forEach { $0.resume() }
            await withCheckedContinuation { continuation = $0 }
        }
        guard !results.isEmpty else { throw StubError.exhausted }
        let result = results.removeFirst()
        let data: Data
        switch result {
        case let .success(count):
            let itemID = body?["itemId"] as? String ?? "line-001"
            data = try JSONSerialization.data(withJSONObject: ["itemId": itemID, "studyCount": count])
        case let .snapshot(rows):
            data = try JSONEncoder().encode(CourseProgressSnapshotDTO(progress: rows))
        case let .failure(error):
            throw error
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }

    func eventIDs() -> [String] { capturedEventIDs }

    func waitUntilSuspended() async {
        if suspended { return }
        await withCheckedContinuation { observers.append($0) }
    }

    func release() {
        suspended = false
        let value = continuation
        continuation = nil
        value?.resume()
    }
}

private final class LockedValues: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String]

    init(_ values: [String]) { self.values = values }

    func next() -> String {
        lock.lock()
        defer { lock.unlock() }
        return values.isEmpty ? "unexpected-event" : values.removeFirst()
    }
}
