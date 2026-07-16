import Foundation
import XCTest
@testable import WordLoopCore

final class WordLoopCoreTests: XCTestCase {
    func testModuleIsAvailable() {
        XCTAssertEqual(WordLoopCoreModule.name, "WordLoopCore")
    }

    func testStableIdentifiersAcceptContractValues() throws {
        let courseID = try XCTUnwrap(CourseID(rawValue: "modern-family-s01e01"))
        let entryID = try XCTUnwrap(EntryID(rawValue: "s01e01-0003"))
        let collectionID = try XCTUnwrap(CourseCollectionID(rawValue: "voa-level-2"))

        XCTAssertEqual(courseID.rawValue, "modern-family-s01e01")
        XCTAssertEqual(entryID.description, "s01e01-0003")
        XCTAssertEqual(collectionID.description, "voa-level-2")
    }

    func testStableIdentifiersRejectValuesOutsideContractPattern() {
        let invalidValues = [
            "", "-course", "course-", "course--one", "Course", "course_one",
            "course/one", "course.one", "course%2fone", "课程", " course", "course ",
        ]

        for value in invalidValues {
            XCTAssertNil(CourseID(rawValue: value), "CourseID accepted \(value)")
            XCTAssertNil(EntryID(rawValue: value), "EntryID accepted \(value)")
            XCTAssertNil(CourseCollectionID(rawValue: value), "CourseCollectionID accepted \(value)")
        }
    }

    func testStableIdentifiersRoundTripThroughCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let courseID = try XCTUnwrap(CourseID(rawValue: "ielts-high-frequency"))
        let entryID = try XCTUnwrap(EntryID(rawValue: "abandon"))
        let collectionID = try XCTUnwrap(CourseCollectionID(rawValue: "ielts"))

        XCTAssertEqual(try decoder.decode(CourseID.self, from: encoder.encode(courseID)), courseID)
        XCTAssertEqual(try decoder.decode(EntryID.self, from: encoder.encode(entryID)), entryID)
        XCTAssertEqual(try decoder.decode(CourseCollectionID.self, from: encoder.encode(collectionID)), collectionID)
    }

    func testStableIdentifiersFailClosedWhileDecoding() {
        let invalid = Data("\"Modern Family\"".utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(CourseID.self, from: invalid))
        XCTAssertThrowsError(try JSONDecoder().decode(EntryID.self, from: invalid))
        XCTAssertThrowsError(try JSONDecoder().decode(CourseCollectionID.self, from: invalid))
    }

    func testEnumsExposeOnlyContractRawValues() throws {
        XCTAssertEqual(StudyMode.allCases.map(\.rawValue), ["listen", "repeat"])
        XCTAssertEqual(CourseKind.allCases.map(\.rawValue), ["word", "sentence"])
        XCTAssertEqual(CoursePracticeOrder.allCases.map(\.rawValue), ["random", "sequential"])
        XCTAssertEqual(CourseAvailability.allCases.map(\.rawValue), ["available", "hidden", "retired"])

        XCTAssertNil(StudyMode(rawValue: "LISTEN"))
        XCTAssertNil(CourseKind(rawValue: "video"))
        XCTAssertNil(CoursePracticeOrder(rawValue: "adaptive"))
        XCTAssertNil(CourseAvailability(rawValue: "installed"))

        let invalid = Data("\"unknown\"".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(StudyMode.self, from: invalid))
        XCTAssertThrowsError(try JSONDecoder().decode(CourseKind.self, from: invalid))
        XCTAssertThrowsError(try JSONDecoder().decode(CoursePracticeOrder.self, from: invalid))
        XCTAssertThrowsError(try JSONDecoder().decode(CourseAvailability.self, from: invalid))
    }

    func testCatalogAndDescriptorPreserveValueSemanticsAndCodable() throws {
        let fixture = makeCatalog()
        let copy = fixture

        XCTAssertEqual(copy, fixture)
        XCTAssertEqual(copy.hashValue, fixture.hashValue)
        XCTAssertEqual(copy.defaultCourseID.description, "modern-family-s01e01")
        XCTAssertEqual(copy.collections.first?.id.description, "modern-family-s01")
        XCTAssertEqual(copy.courses.first?.manifestLocation, "courses/modern-family-s01e01/1/course.json")

        let encoded = try JSONEncoder().encode(fixture)
        XCTAssertEqual(try JSONDecoder().decode(CourseCatalog.self, from: encoded), fixture)
    }

    func testCourseAndEntriesPreserveURLHighlightsAndOptionalValues() throws {
        let descriptor = makeDescriptor()
        let audioURL = URL(fileURLWithPath: "/tmp/WordLoop/audio/s01e01-0003.m4a")
        let sentence = CourseEntry(
            id: try XCTUnwrap(EntryID(rawValue: "s01e01-0003")),
            text: "Phil, would you get them?",
            translation: "菲尔 把他们叫下来好吗",
            phonetic: nil,
            highlights: ["get them"],
            audioURL: audioURL,
            durationMilliseconds: 1_000
        )
        let word = CourseEntry(
            id: try XCTUnwrap(EntryID(rawValue: "abandon")),
            text: "abandon",
            translation: nil,
            phonetic: "ə'bændən",
            highlights: [],
            audioURL: URL(fileURLWithPath: "/tmp/WordLoop/audio/abandon.m4a"),
            durationMilliseconds: 836
        )
        let course = Course(descriptor: descriptor, entries: [sentence, word])

        XCTAssertEqual(course.id, descriptor.id)
        XCTAssertTrue(course.entries[0].audioURL.isFileURL)
        XCTAssertEqual(course.entries[0].highlights, ["get them"])
        XCTAssertNil(course.entries[0].phonetic)
        XCTAssertNil(course.entries[1].translation)

        let encoded = try JSONEncoder().encode(course)
        XCTAssertEqual(try JSONDecoder().decode(Course.self, from: encoded), course)
    }

    func testAllPublicDomainValuesAreSendable() {
        requireSendable(CourseID.self)
        requireSendable(EntryID.self)
        requireSendable(CourseCollectionID.self)
        requireSendable(StudyMode.self)
        requireSendable(CourseKind.self)
        requireSendable(CoursePracticeOrder.self)
        requireSendable(CourseAvailability.self)
        requireSendable(CourseCatalog.self)
        requireSendable(CourseCollectionDescriptor.self)
        requireSendable(CourseDescriptor.self)
        requireSendable(Course.self)
        requireSendable(CourseEntry.self)
    }

    private func makeCatalog() -> CourseCatalog {
        CourseCatalog(
            schemaVersion: 1,
            generatedAt: "2026-07-16T00:00:00Z",
            defaultCourseID: CourseID(rawValue: "modern-family-s01e01")!,
            collections: [
                CourseCollectionDescriptor(
                    id: CourseCollectionID(rawValue: "modern-family-s01")!,
                    label: "DIALOGUE COURSE",
                    title: "摩登家庭 · 第一季",
                    subtitle: "5 集对白课程"
                ),
            ],
            courses: [makeDescriptor()]
        )
    }

    private func makeDescriptor() -> CourseDescriptor {
        CourseDescriptor(
            id: CourseID(rawValue: "modern-family-s01e01")!,
            collectionID: CourseCollectionID(rawValue: "modern-family-s01")!,
            title: "Modern Family · S01E01",
            subtitle: "Pilot · 91 learning sentences",
            description: "用真实对白练习听力、表达和跟读。",
            kind: .sentence,
            practiceOrder: .sequential,
            contentVersion: 1,
            minimumAppVersion: "1.0.0",
            manifestLocation: "courses/modern-family-s01e01/1/course.json",
            manifestSHA256: String(repeating: "a", count: 64),
            downloadSize: 1_502_479,
            availability: .available
        )
    }
}

private func requireSendable<T: Sendable>(_: T.Type) {}
