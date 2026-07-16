import Foundation
import XCTest
import WordLoopCore
import WordLoopDesignSystem
@testable import WordLoopFeatures

final class StudySelectionTests: XCTestCase {
    func testEligibleEntriesKeepManifestOrderAndExcludeMastered() {
        let entries = makeEntries(4)
        let counts = [entries[0].id: -1, entries[1].id: 2, entries[2].id: 3, entries[3].id: 99]

        XCTAssertEqual(
            StudySelection.eligibleEntries(in: entries, studyCounts: counts).map(\.id),
            [entries[0].id, entries[1].id]
        )
    }

    func testSequentialStartsFirstThenAdvancesAndWraps() {
        let entries = makeEntries(4)
        let counts = [entries[1].id: 3]

        XCTAssertEqual(select(entries, .sequential, counts, nil, 99)?.id, entries[0].id)
        XCTAssertEqual(select(entries, .sequential, counts, entries[0].id, 99)?.id, entries[2].id)
        XCTAssertEqual(select(entries, .sequential, counts, entries[3].id, 99)?.id, entries[0].id)
    }

    func testSelectionExcludesCurrentButFallsBackWhenItIsOnlyEligibleEntry() {
        let entries = makeEntries(3)
        let alternativesExist = [entries[0].id: 1, entries[1].id: 0, entries[2].id: 3]
        XCTAssertEqual(select(entries, .sequential, alternativesExist, entries[0].id, 0)?.id, entries[1].id)

        let onlyCurrent = [entries[0].id: 1, entries[1].id: 3, entries[2].id: 3]
        XCTAssertEqual(select(entries, .sequential, onlyCurrent, entries[0].id, 0)?.id, entries[0].id)
        XCTAssertEqual(select(entries, .random, onlyCurrent, entries[0].id, 42)?.id, entries[0].id)

        let exhausted = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, 3) })
        XCTAssertNil(select(entries, .sequential, exhausted, entries[0].id, 0))
    }

    func testRandomSelectionUsesDeterministicNormalizedIndex() {
        let entries = makeEntries(4)

        XCTAssertEqual(select(entries, .random, [:], entries[0].id, 0)?.id, entries[1].id)
        XCTAssertEqual(select(entries, .random, [:], entries[0].id, 4)?.id, entries[2].id)
        XCTAssertEqual(select(entries, .random, [:], entries[0].id, -1)?.id, entries[3].id)
    }

    func testPaletteSelectionAvoidsCurrentAndUsesExplicitRandomIndex() throws {
        let palettes = Array(PosterPalette.all.prefix(3))
        let selected = try XCTUnwrap(StudySelection.palette(
            from: palettes,
            excluding: palettes[1].id,
            randomIndex: 1
        ))
        XCTAssertEqual(selected.id, palettes[2].id)
        XCTAssertNotEqual(selected.id, palettes[1].id)

        XCTAssertEqual(
            StudySelection.palette(from: [palettes[0]], excluding: palettes[0].id, randomIndex: 99),
            palettes[0]
        )
        XCTAssertNil(StudySelection.palette(from: [], excluding: nil, randomIndex: 0))
    }

    private func select(
        _ entries: [CourseEntry],
        _ order: CoursePracticeOrder,
        _ counts: [EntryID: Int],
        _ current: EntryID?,
        _ randomIndex: Int
    ) -> CourseEntry? {
        StudySelection.entry(
            in: entries,
            order: order,
            studyCounts: counts,
            excluding: current,
            randomIndex: randomIndex
        )
    }

    private func makeEntries(_ count: Int) -> [CourseEntry] {
        (1...count).map { index in
            CourseEntry(
                id: EntryID(rawValue: "entry-\(index)")!,
                text: "Entry \(index)",
                translation: nil,
                phonetic: nil,
                highlights: [],
                audioURL: URL(fileURLWithPath: "/tmp/entry-\(index).m4a"),
                durationMilliseconds: 1_000
            )
        }
    }
}
