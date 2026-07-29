import Foundation
import XCTest
import WordLoopCore
import WordLoopDesignSystem
@testable import WordLoopFeatures

final class StudyProjectionTests: XCTestCase {
    func testCatalogProjectionFiltersUnavailableCoursesAndEmptyCollections() throws {
        let fixtures = makeCatalogFixtures()
        let catalog = CourseCatalog(
            schemaVersion: 1,
            generatedAt: "2026-07-16T00:00:00Z",
            defaultCourseID: fixtures.available.id,
            collections: [fixtures.collection, fixtures.emptyCollection],
            courses: [fixtures.available, fixtures.hidden, fixtures.retired]
        )

        let state = StudyProjection.courseDrawerState(
            catalog: catalog,
            selectedCourseID: fixtures.available.id,
            completionCounts: [fixtures.available.id: 2]
        )

        XCTAssertEqual(state.collections.map(\.id), [fixtures.collection.id.rawValue])
        XCTAssertEqual(state.collections[0].courses.map(\.id), [fixtures.available.id.rawValue])
        XCTAssertEqual(state.collections[0].courses[0].completionCount, 2)
        XCTAssertTrue(state.collections[0].courses[0].isSelected)
        XCTAssertEqual(state.expandedCollectionID, fixtures.collection.id.rawValue)
    }

    func testSentenceProjectionUsesSafeCharacterHighlightsAndDoesNotRewriteText() {
        let entry = makeEntry(
            id: "sentence-1",
            text: "你好 👋 你好",
            translation: "  你好  ",
            phonetic: nil,
            highlights: ["你好", "好", "not found"]
        )

        let item = StudyProjection.studyShellItem(entry: entry, kind: .sentence)

        XCTAssertEqual(item.english, entry.text)
        XCTAssertEqual(item.translation, "你好")
        XCTAssertNil(item.phonetic)
        XCTAssertEqual(item.resolvedHighlightRanges().map { String(item.english[$0]) }, ["你好", "你好"])
        XCTAssertEqual(item.highlightRanges, [.init(0, 2), .init(5, 7)])
    }

    func testWordPhoneticFormattingAndNilFieldsRemainEmpty() {
        let plain = makeEntry(
            id: "word-1",
            text: "comfortable",
            translation: "舒服的",
            phonetic: "ˈkʌmftəbl"
        )
        let wrapped = makeEntry(
            id: "word-2",
            text: "academic",
            translation: nil,
            phonetic: "/ˌækəˈdemɪk/"
        )
        let empty = makeEntry(id: "word-3", text: "empty", translation: "  ", phonetic: " // ")

        XCTAssertEqual(StudyProjection.studyShellItem(entry: plain, kind: .word).phonetic, "/ˈkʌmftəbl/")
        XCTAssertEqual(StudyProjection.studyShellItem(entry: wrapped, kind: .word).phonetic, "/ˌækəˈdemɪk/")

        let emptyItem = StudyProjection.studyShellItem(entry: empty, kind: .word)
        XCTAssertNil(emptyItem.phonetic)
        XCTAssertEqual(emptyItem.translation, "")
    }

    func testCourseEntryProjectsToAtomicStudyShellState() throws {
        let descriptor = makeDescriptor(id: "course-1", collectionID: "collection-1", kind: .word)
        let entries = [
            makeEntry(id: "word-1", text: "first", translation: "第一", phonetic: "fɜːst"),
            makeEntry(id: "word-2", text: "second", translation: "第二", phonetic: "sekənd"),
        ]
        let course = Course(descriptor: descriptor, entries: entries)
        let collection = makeCollection(id: "collection-1")
        let palette = try XCTUnwrap(PosterPalette.all.first(where: { $0.id == "sun" }))

        let state = try XCTUnwrap(StudyProjection.studyShellState(
            course: course,
            collection: collection,
            currentEntryID: entries[1].id,
            palette: palette,
            mode: .listen,
            visibility: .focus,
            masteryCount: 7,
            isAutoplayEnabled: true
        ))

        XCTAssertEqual(state.palette, palette)
        XCTAssertEqual(state.courseLabel, descriptor.title.uppercased())
        XCTAssertEqual(state.courseTitle, collection.title)
        XCTAssertEqual(state.currentIndex, 2)
        XCTAssertEqual(state.totalCount, 2)
        XCTAssertEqual(state.item.id, entries[1].id.rawValue)
        XCTAssertEqual(state.visibility, .full)
        XCTAssertEqual(state.mode, .listen)
        XCTAssertEqual(state.masteryCount, 3)
        XCTAssertTrue(state.isAutoplayEnabled)
        XCTAssertNil(StudyProjection.studyShellState(
            course: course,
            collection: collection,
            currentEntryID: EntryID(rawValue: "missing")!,
            palette: palette,
            mode: .listen,
            visibility: .full,
            masteryCount: 0,
            isAutoplayEnabled: false
        ))
    }

    func testProgressProjectionUsesCourseEntriesAndClampedCounts() {
        let descriptor = makeDescriptor(id: "course-1", collectionID: "collection-1", kind: .word)
        let first = makeEntry(id: "word-1", text: "first", translation: "第一", phonetic: "fɜːst")
        let second = makeEntry(id: "word-2", text: "second", translation: nil, phonetic: nil)
        let course = Course(descriptor: descriptor, entries: [first, second])

        let state = StudyProjection.progressDrawerState(
            course: course,
            studyCounts: [first.id: 99, second.id: -2]
        )

        XCTAssertEqual(state.summary.courseTitle, descriptor.title)
        XCTAssertEqual(state.summary.totalItemCount, 2)
        XCTAssertEqual(state.summary.totalStudies, 3)
        XCTAssertEqual(state.summary.masteredCount, 1)
        XCTAssertEqual(state.entries[0].secondaryText, "/fɜːst/ · 第一")
        XCTAssertEqual(state.entries[0].studyCount, 3)
        XCTAssertEqual(state.entries[1].secondaryText, "")
        XCTAssertEqual(state.entries[1].studyCount, 0)
    }

    private func makeCatalogFixtures() -> (
        collection: CourseCollectionDescriptor,
        emptyCollection: CourseCollectionDescriptor,
        available: CourseDescriptor,
        hidden: CourseDescriptor,
        retired: CourseDescriptor
    ) {
        let collection = makeCollection(id: "collection-1")
        let empty = makeCollection(id: "collection-2")
        return (
            collection,
            empty,
            makeDescriptor(id: "available", collectionID: collection.id.rawValue, availability: .available),
            makeDescriptor(id: "hidden", collectionID: collection.id.rawValue, availability: .hidden),
            makeDescriptor(id: "retired", collectionID: collection.id.rawValue, availability: .retired)
        )
    }

    private func makeCollection(id: String) -> CourseCollectionDescriptor {
        CourseCollectionDescriptor(
            id: CourseCollectionID(rawValue: id)!,
            label: "DIALOGUE COURSE",
            title: "Collection \(id)",
            subtitle: "Subtitle \(id)"
        )
    }

    private func makeDescriptor(
        id: String,
        collectionID: String,
        kind: CourseKind = .sentence,
        availability: CourseAvailability = .available
    ) -> CourseDescriptor {
        CourseDescriptor(
            id: CourseID(rawValue: id)!,
            collectionID: CourseCollectionID(rawValue: collectionID)!,
            title: "Course \(id)",
            subtitle: "Subtitle \(id)",
            description: "Description \(id)",
            kind: kind,
            practiceOrder: kind == .word ? .random : .sequential,
            contentVersion: 1,
            minimumAppVersion: "1.0.0",
            manifestLocation: "courses/\(id).json",
            manifestSHA256: String(repeating: "a", count: 64),
            downloadSize: 1,
            availability: availability
        )
    }

    private func makeEntry(
        id: String,
        text: String,
        translation: String?,
        phonetic: String?,
        highlights: [String] = []
    ) -> CourseEntry {
        CourseEntry(
            id: EntryID(rawValue: id)!,
            text: text,
            translation: translation,
            phonetic: phonetic,
            highlights: highlights,
            audioURL: URL(fileURLWithPath: "/tmp/\(id).m4a"),
            durationMilliseconds: 1_000
        )
    }
}
