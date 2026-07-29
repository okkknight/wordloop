import XCTest
import WordLoopDesignSystem
@testable import WordLoopFeatures

final class ProgressDrawerModelTests: XCTestCase {
    func testSentenceBaselineMatchesLockedSummaryAndRepresentativeRows() {
        let state = ProgressDrawerViewState.sentenceBaseline
        XCTAssertEqual(state.summary.courseTitle, "Modern Family · S01E01")
        XCTAssertEqual(state.summary.totalStudiesLabel, "0 / 273")
        XCTAssertEqual(state.summary.totalStudies, 0)
        XCTAssertEqual(state.summary.maximumStudies, 273)
        XCTAssertEqual(state.summary.masteredCount, 0)
        XCTAssertEqual(state.summary.learningCount, 91)
        XCTAssertEqual(state.summary.progressFraction, 0)
        XCTAssertEqual(state.searchPlaceholder, "搜索句子或中文翻译")
        XCTAssertEqual(state.entries.count, 10)
        XCTAssertEqual(state.entries[0].primaryText, "Phil, would you get them?")
        XCTAssertEqual(state.entries[0].secondaryText, "菲尔 把他们叫下来好吗")
        XCTAssertEqual(state.entries[1].primaryText, "Kids? Get down here!")
        XCTAssertEqual(state.entries[2].primaryText, "Why are you guys yelling at us when we're way upstairs?")
        XCTAssertTrue(state.entries.allSatisfy { $0.countLabel == "0 / 3" })
    }

    func testWordFixtureUsesPhoneticMeaningFormatAndWordPlaceholder() {
        let state = ProgressDrawerViewState.word
        XCTAssertEqual(state.searchPlaceholder, "搜索单词或中文释义")
        XCTAssertGreaterThanOrEqual(state.entries.count, 3)
        XCTAssertTrue(state.entries.allSatisfy { $0.kind == .word })
        XCTAssertTrue(state.entries.allSatisfy { $0.secondaryText.hasPrefix("/") && $0.secondaryText.contains("/ · ") })
    }

    func testEntryClampsCountsAndExposesCompletionSemantics() {
        var low = ProgressDrawerEntry(id: "low", kind: .sentence, primaryText: "Low", secondaryText: "低", studyCount: -9)
        XCTAssertEqual(low.studyCount, 0)
        XCTAssertEqual(low.countLabel, "0 / 3")
        XCTAssertFalse(low.isMastered)

        low.studyCount = 99
        XCTAssertEqual(low.studyCount, 3)
        XCTAssertTrue(low.isMastered)
        XCTAssertTrue(low.accessibilityLabel.contains("已学习 3 次，共 3 次"))
        XCTAssertTrue(low.accessibilityLabel.hasSuffix("已掌握"))
    }

    func testSummaryClampsInvalidStatisticsAndZeroDenominatorIsSafe() {
        let empty = ProgressDrawerSummary(courseTitle: "Empty", totalItemCount: -1, totalStudies: 999, masteredCount: 999)
        XCTAssertEqual(empty.totalItemCount, 0)
        XCTAssertEqual(empty.maximumStudies, 0)
        XCTAssertEqual(empty.totalStudies, 0)
        XCTAssertEqual(empty.masteredCount, 0)
        XCTAssertEqual(empty.learningCount, 0)
        XCTAssertEqual(empty.progressFraction, 0)

        let bounded = ProgressDrawerSummary(courseTitle: "Bounded", totalItemCount: 2, totalStudies: 99, masteredCount: 99)
        XCTAssertEqual(bounded.maximumStudies, 6)
        XCTAssertEqual(bounded.totalStudies, 6)
        XCTAssertEqual(bounded.masteredCount, 2)
        XCTAssertEqual(bounded.learningCount, 0)
        XCTAssertEqual(bounded.progressFraction, 1)

        let huge = ProgressDrawerSummary(courseTitle: "Huge", totalItemCount: .max, totalStudies: .max, masteredCount: .max)
        XCTAssertEqual(huge.maximumStudies, (Int.max / 3) * 3)
        XCTAssertLessThanOrEqual(huge.progressFraction, 1)
    }

    func testMixedAndCompleteFixturesRemainInternallyConsistent() {
        let mixed = ProgressDrawerViewState.mixed
        XCTAssertEqual(Array(mixed.entries.prefix(4).map(\.studyCount)), [0, 1, 2, 3])
        XCTAssertEqual(mixed.summary.totalStudies, mixed.entries.reduce(0) { $0 + $1.studyCount })
        XCTAssertEqual(mixed.summary.masteredCount, 1)
        XCTAssertEqual(mixed.summary.learningCount, 90)
        XCTAssertEqual(mixed.summary.progressFraction, 6.0 / 273.0, accuracy: 0.000_001)
        XCTAssertTrue(mixed.entries[3].isMastered)

        let complete = ProgressDrawerViewState.complete
        XCTAssertEqual(complete.summary.totalStudies, 273)
        XCTAssertEqual(complete.summary.masteredCount, 91)
        XCTAssertEqual(complete.summary.learningCount, 0)
        XCTAssertEqual(complete.summary.progressFraction, 1)
        XCTAssertTrue(complete.entries.allSatisfy(\.isMastered))
    }

    @MainActor
    func testSearchTrimsAndMatchesEnglishChineseAndPhoneticCaseInsensitive() {
        let sentenceStore = ProgressDrawerStore()
        sentenceStore.updateQuery("  KIDS?  ")
        XCTAssertEqual(sentenceStore.filteredEntries.map(\.id), ["s01e01-0007"])
        sentenceStore.updateQuery("婴儿油")
        XCTAssertEqual(sentenceStore.filteredEntries.map(\.id), ["s01e01-0019"])

        let wordStore = ProgressDrawerStore(state: .word)
        wordStore.updateQuery("  COMFORTABLE ")
        XCTAssertEqual(wordStore.filteredEntries.map(\.id), ["comfortable"])
        wordStore.updateQuery("KʌMFT")
        XCTAssertEqual(wordStore.filteredEntries.map(\.id), ["comfortable"])
        wordStore.updateQuery("学术")
        XCTAssertEqual(wordStore.filteredEntries.map(\.id), ["academic"])
    }

    @MainActor
    func testEmptyQueryResultAndClearRestoreEntries() {
        let store = ProgressDrawerStore()
        store.updateQuery("absent fixture")
        XCTAssertTrue(store.filteredEntries.isEmpty)
        store.updateQuery("   ")
        XCTAssertEqual(store.filteredEntries, store.state.entries)
    }

    @MainActor
    func testPresentAndDismissReasonsRecordOnlyPresentationActions() {
        for reason in [ProgressDrawerDismissReason.header, .backdrop] {
            let store = ProgressDrawerStore()
            let originalSummary = store.state.summary
            let originalEntries = store.state.entries
            store.present()
            XCTAssertTrue(store.state.isPresented)
            XCTAssertEqual(store.lastAction, .presented)
            XCTAssertNil(store.state.lastDismissReason)

            store.dismiss(reason: reason)
            XCTAssertFalse(store.state.isPresented)
            XCTAssertEqual(store.state.lastDismissReason, reason)
            XCTAssertEqual(store.lastAction, .dismissed(reason))
            XCTAssertEqual(store.state.summary, originalSummary)
            XCTAssertEqual(store.state.entries, originalEntries)
        }
    }

    @MainActor
    func testOnlyDominantRightDragPastThresholdDismisses() {
        let store = ProgressDrawerStore()
        store.present()

        XCTAssertFalse(store.handleDrag(horizontal: 72, vertical: 0))
        XCTAssertFalse(store.handleDrag(horizontal: 90, vertical: 100))
        XCTAssertFalse(store.handleDrag(horizontal: -100, vertical: 0))
        XCTAssertTrue(store.state.isPresented)

        XCTAssertTrue(store.handleDrag(horizontal: 72.1, vertical: 20))
        XCTAssertFalse(store.state.isPresented)
        XCTAssertEqual(store.state.lastDismissReason, .swipe)
        XCTAssertEqual(store.lastAction, .dismissed(.swipe))
    }

    func testFixtureArgumentsCompose() {
        let mixed = ProgressDrawerViewState.fixture(arguments: [
            "WordLoop",
            "-wordloop-progress-drawer",
            "-wordloop-progress-mixed",
            "-wordloop-progress-query", "Kids",
        ])
        XCTAssertTrue(mixed.isPresented)
        XCTAssertEqual(mixed.summary.totalStudies, 6)
        XCTAssertEqual(mixed.query, "Kids")

        let emptyWord = ProgressDrawerViewState.fixture(arguments: [
            "WordLoop",
            "-wordloop-progress-word",
            "-wordloop-progress-empty",
        ])
        XCTAssertEqual(emptyWord.entries.first?.kind, .word)
        XCTAssertTrue(emptyWord.filteredEntries.isEmpty)
    }

    func testDrawerSemanticTextAndBoundaryRolesMeetAllPaletteThresholds() {
        for palette in PosterPalette.all {
            let secondaryText = palette.ink.composited(
                over: palette.background,
                opacity: WordLoopLayerOpacity.progressSecondaryText
            )
            let boundary = palette.ink.composited(
                over: palette.background,
                opacity: WordLoopLayerOpacity.progressBoundary
            )

            XCTAssertGreaterThanOrEqual(secondaryText.contrastRatio(with: palette.background), 4.5, palette.id)
            XCTAssertGreaterThanOrEqual(boundary.contrastRatio(with: palette.background), 3.0, palette.id)
            XCTAssertGreaterThanOrEqual(palette.accessibleAccentText.contrastRatio(with: palette.background), 4.5, palette.id)
        }
    }

    @MainActor
    func testStoreConstructsWithoutBusinessServices() {
        let store = ProgressDrawerStore(state: .mixed)
        XCTAssertEqual(store.state.summary.courseTitle, "Modern Family · S01E01")
        XCTAssertNil(store.lastAction)
    }
}
