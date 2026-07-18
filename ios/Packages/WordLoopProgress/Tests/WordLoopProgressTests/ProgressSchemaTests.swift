import Foundation
import SwiftData
import XCTest
@testable import WordLoopProgress

@MainActor
final class ProgressSchemaTests: XCTestCase {
    func testSchemaVersionModelsAndMigrationEntryAreExplicit() {
        XCTAssertEqual(WordLoopProgressSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(WordLoopProgressSchemaV1.models.count, 6)
        XCTAssertEqual(WordLoopProgressMigrationPlan.schemas.count, 1)
        XCTAssertTrue(WordLoopProgressMigrationPlan.stages.isEmpty)
    }

    func testStableCompositeKeysDoNotCollideAcrossBoundariesOrModes() {
        let ambiguousA = ProgressRecord.makeID(
            userID: "a:b", modeRawValue: "listen", courseID: "course", entryID: "entry"
        )
        let ambiguousB = ProgressRecord.makeID(
            userID: "a", modeRawValue: "b:listen", courseID: "course", entryID: "entry"
        )
        XCTAssertNotEqual(ambiguousA, ambiguousB)
        XCTAssertNotEqual(
            ProgressRecord.makeID(userID: "user", modeRawValue: "listen", courseID: "course", entryID: "entry"),
            ProgressRecord.makeID(userID: "user", modeRawValue: "repeat", courseID: "course", entryID: "entry")
        )
        XCTAssertEqual(
            CourseCompletionRecord.makeID(userID: "user", courseID: "course"),
            CourseCompletionRecord.makeID(userID: "user", courseID: "course")
        )
    }

    func testEveryV1ModelRoundTripsInMemory() throws {
        let container = try WordLoopProgressContainer.makeInMemory()
        let context = container.mainContext
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let attempted = created.addingTimeInterval(10)
        let acknowledged = created.addingTimeInterval(20)

        context.insert(StudyIdentity(
            identityID: "current", userID: "name:alice", username: "alice",
            createdAt: created, updatedAt: attempted
        ))
        context.insert(ProgressRecord(
            userID: "name:alice", modeRawValue: "listen", courseID: "course-a",
            entryID: "line-001", studyCount: 2, updatedAt: attempted
        ))
        context.insert(ProgressEvent(
            clientEventID: "event-001", userID: "name:alice", modeRawValue: "listen",
            courseID: "course-a", entryID: "line-001",
            kindRawValue: ProgressEventKind.increment.rawValue,
            stateRawValue: ProgressOutboxState.acknowledged.rawValue,
            createdAt: created, lastAttemptAt: attempted, acknowledgedAt: acknowledged, attemptCount: 2
        ))
        context.insert(CourseCompletionRecord(
            userID: "name:alice", courseID: "course-a", completionCount: 4, updatedAt: attempted
        ))
        context.insert(CourseCompletionEvent(
            clientEventID: "completion-001", userID: "name:alice", courseID: "course-a",
            stateRawValue: ProgressOutboxState.pending.rawValue,
            createdAt: created, lastAttemptAt: attempted, attemptCount: 1
        ))
        context.insert(CoursePreference(
            userID: "name:alice", recentCourseID: "course-a", updatedAt: attempted
        ))
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyIdentity>()).first?.username, "alice")
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProgressRecord>()).first?.studyCount, 2)
        let event = try XCTUnwrap(context.fetch(FetchDescriptor<ProgressEvent>()).first)
        XCTAssertEqual(event.kindRawValue, ProgressEventKind.increment.rawValue)
        XCTAssertEqual(event.stateRawValue, ProgressOutboxState.acknowledged.rawValue)
        XCTAssertEqual(event.attemptCount, 2)
        XCTAssertEqual(event.lastAttemptAt, attempted)
        XCTAssertEqual(event.acknowledgedAt, acknowledged)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CourseCompletionRecord>()).first?.completionCount, 4)
        XCTAssertNil(try context.fetch(FetchDescriptor<CourseCompletionEvent>()).first?.acknowledgedAt)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CoursePreference>()).first?.recentCourseID, "course-a")
    }

    func testUniqueBusinessKeysKeepOneLogicalRecord() throws {
        let container = try WordLoopProgressContainer.makeInMemory()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(ProgressRecord(
            userID: "name:alice", modeRawValue: "listen", courseID: "course-a",
            entryID: "line-001", studyCount: 1, updatedAt: now
        ))
        try context.save()
        context.insert(ProgressRecord(
            userID: "name:alice", modeRawValue: "listen", courseID: "course-a",
            entryID: "line-001", studyCount: 3, updatedAt: now.addingTimeInterval(1)
        ))
        try context.save()

        let records = try context.fetch(FetchDescriptor<ProgressRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.studyCount, 3)
    }

    func testPersistentContainerRestoresAllModelsAfterReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "wordloop-progress-schema-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "progress.store")
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        do {
            let container = try WordLoopProgressContainer.makePersistent(storeURL: storeURL)
            let context = container.mainContext
            context.insert(StudyIdentity(identityID: "current", userID: "name:alice", username: nil, createdAt: now, updatedAt: now))
            context.insert(ProgressRecord(userID: "name:alice", modeRawValue: "repeat", courseID: "course-a", entryID: "line-001", studyCount: 1, updatedAt: now))
            context.insert(ProgressEvent(clientEventID: "event-001", userID: "name:alice", modeRawValue: "repeat", courseID: "course-a", entryID: "line-001", kindRawValue: "increment", stateRawValue: "pending", createdAt: now))
            context.insert(CourseCompletionRecord(userID: "name:alice", courseID: "course-a", completionCount: 1, updatedAt: now))
            context.insert(CourseCompletionEvent(clientEventID: "completion-001", userID: "name:alice", courseID: "course-a", stateRawValue: "pending", createdAt: now))
            context.insert(CoursePreference(userID: "name:alice", recentCourseID: "course-a", updatedAt: now))
            try context.save()
        }

        let reopened = try WordLoopProgressContainer.makePersistent(storeURL: storeURL)
        let context = reopened.mainContext
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StudyIdentity>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProgressRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProgressEvent>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CourseCompletionRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CourseCompletionEvent>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CoursePreference>()), 1)
    }
}
