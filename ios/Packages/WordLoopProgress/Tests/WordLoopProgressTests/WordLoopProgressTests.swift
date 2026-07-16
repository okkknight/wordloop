import XCTest
import WordLoopCore
@testable import WordLoopProgress

final class WordLoopProgressTests: XCTestCase {
    func testModuleIsAvailable() {
        XCTAssertEqual(WordLoopProgressModule.name, "WordLoopProgress")
    }

    func testSnapshotStartsEmpty() async throws {
        let repository = TemporaryProgressRepository()

        let snapshot = await repository.snapshot(
            courseID: try courseID("modern-family-s01e01"),
            mode: .listen
        )

        XCTAssertTrue(snapshot.isEmpty)
    }

    func testRecordIncrementsAndReturnsResultingCount() async throws {
        let repository = TemporaryProgressRepository()
        let courseID = try courseID("modern-family-s01e01")
        let entryID = try entryID("s01e01-0001")

        let first = await repository.record(courseID: courseID, mode: .listen, entryID: entryID)
        let second = await repository.record(courseID: courseID, mode: .listen, entryID: entryID)
        let snapshot = await repository.snapshot(courseID: courseID, mode: .listen)

        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 2)
        XCTAssertEqual(snapshot, [entryID: 2])
    }

    func testRecordClampsAtThree() async throws {
        let repository = TemporaryProgressRepository()
        let courseID = try courseID("modern-family-s01e01")
        let entryID = try entryID("s01e01-0001")

        var results: [Int] = []
        for _ in 0..<5 {
            results.append(
                await repository.record(courseID: courseID, mode: .listen, entryID: entryID)
            )
        }
        let snapshot = await repository.snapshot(courseID: courseID, mode: .listen)

        XCTAssertEqual(results, [1, 2, 3, 3, 3])
        XCTAssertEqual(snapshot, [entryID: 3])
    }

    func testMasterSetsCountToThreeAndRecordKeepsItClamped() async throws {
        let repository = TemporaryProgressRepository()
        let courseID = try courseID("modern-family-s01e01")
        let entryID = try entryID("s01e01-0001")

        let mastered = await repository.master(courseID: courseID, mode: .listen, entryID: entryID)
        let recorded = await repository.record(courseID: courseID, mode: .listen, entryID: entryID)
        let snapshot = await repository.snapshot(courseID: courseID, mode: .listen)

        XCTAssertEqual(mastered, 3)
        XCTAssertEqual(recorded, 3)
        XCTAssertEqual(snapshot, [entryID: 3])
    }

    func testProgressIsPartitionedByCourseModeAndEntry() async throws {
        let repository = TemporaryProgressRepository()
        let firstCourse = try courseID("modern-family-s01e01")
        let secondCourse = try courseID("modern-family-s01e02")
        let firstEntry = try entryID("s01e01-0001")
        let secondEntry = try entryID("s01e01-0002")

        _ = await repository.record(courseID: firstCourse, mode: .listen, entryID: firstEntry)
        _ = await repository.record(courseID: firstCourse, mode: .listen, entryID: secondEntry)
        _ = await repository.record(courseID: firstCourse, mode: .repeat, entryID: firstEntry)
        _ = await repository.master(courseID: secondCourse, mode: .listen, entryID: firstEntry)
        let firstListen = await repository.snapshot(courseID: firstCourse, mode: .listen)
        let firstRepeat = await repository.snapshot(courseID: firstCourse, mode: .repeat)
        let secondListen = await repository.snapshot(courseID: secondCourse, mode: .listen)
        let secondRepeat = await repository.snapshot(courseID: secondCourse, mode: .repeat)

        XCTAssertEqual(firstListen, [firstEntry: 1, secondEntry: 1])
        XCTAssertEqual(firstRepeat, [firstEntry: 1])
        XCTAssertEqual(secondListen, [firstEntry: 3])
        XCTAssertTrue(secondRepeat.isEmpty)
    }

    func testConcurrentRecordsRemainAtomicAndClamped() async throws {
        let repository = TemporaryProgressRepository()
        let courseID = try courseID("modern-family-s01e01")
        let entryID = try entryID("s01e01-0001")

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    _ = await repository.record(
                        courseID: courseID,
                        mode: .listen,
                        entryID: entryID
                    )
                }
            }
        }
        let snapshot = await repository.snapshot(courseID: courseID, mode: .listen)

        XCTAssertEqual(snapshot, [entryID: 3])
    }

    func testResetClearsOnlyRequestedCourseModeAndKeepsCompletionCount() async throws {
        let repository = TemporaryProgressRepository()
        let firstCourse = try courseID("modern-family-s01e01")
        let secondCourse = try courseID("modern-family-s01e02")
        let entry = try entryID("entry-one")
        _ = await repository.record(courseID: firstCourse, mode: .listen, entryID: entry)
        _ = await repository.record(courseID: firstCourse, mode: .repeat, entryID: entry)
        _ = await repository.record(courseID: secondCourse, mode: .listen, entryID: entry)
        _ = await repository.complete(courseID: firstCourse, completionID: "completion-one")

        await repository.reset(courseID: firstCourse, mode: .listen)

        let firstListen = await repository.snapshot(courseID: firstCourse, mode: .listen)
        let firstRepeat = await repository.snapshot(courseID: firstCourse, mode: .repeat)
        let secondListen = await repository.snapshot(courseID: secondCourse, mode: .listen)
        let completions = await repository.completions()
        XCTAssertTrue(firstListen.isEmpty)
        XCTAssertEqual(firstRepeat, [entry: 1])
        XCTAssertEqual(secondListen, [entry: 1])
        XCTAssertEqual(completions, [firstCourse: 1])
    }

    func testCompletionIsSharedAcrossModesAndIdempotentByIdentity() async throws {
        let repository = TemporaryProgressRepository()
        let course = try courseID("modern-family-s01e01")

        let first = await repository.complete(courseID: course, completionID: "completion-one")
        let duplicate = await repository.complete(courseID: course, completionID: "completion-one")
        let second = await repository.complete(courseID: course, completionID: "completion-two")

        XCTAssertEqual(first, 1)
        XCTAssertEqual(duplicate, 1)
        XCTAssertEqual(second, 2)
        let completions = await repository.completions()
        XCTAssertEqual(completions, [course: 2])
    }

    private func courseID(_ rawValue: String) throws -> CourseID {
        try XCTUnwrap(CourseID(rawValue: rawValue))
    }

    private func entryID(_ rawValue: String) throws -> EntryID {
        try XCTUnwrap(EntryID(rawValue: rawValue))
    }
}
