import XCTest
import WordLoopDesignSystem
@testable import WordLoopFeatures

final class CourseDrawerModelTests: XCTestCase {
    func testBaselineContainsLockedCollectionsAndCurrentCourse() throws {
        let state = CourseDrawerViewState.baseline
        XCTAssertEqual(state.collections.map(\.id), ["ielts", "modern-family-s01", "voa-level-2"])
        XCTAssertEqual(state.collections.map(\.label), ["WORD COURSE", "DIALOGUE COURSE", "DIALOGUE COURSE"])
        XCTAssertEqual(state.collections.map(\.title), ["IELTS 高频词", "摩登家庭 · 第一季", "VOA · Level 2"])
        XCTAssertEqual(state.expandedCollectionID, "modern-family-s01")
        XCTAssertFalse(state.isPresented)

        let modernFamily = try XCTUnwrap(state.collections.first(where: { $0.id == "modern-family-s01" }))
        XCTAssertEqual(modernFamily.subtitle, "5 集对白课程")
        XCTAssertEqual(modernFamily.courses.count, 5)
        XCTAssertEqual(modernFamily.courses.map(\.title), [
            "Modern Family · S01E01",
            "Modern Family · S01E02",
            "Modern Family · S01E03",
            "Modern Family · S01E04",
            "Modern Family · S01E05",
        ])
        let selected = try XCTUnwrap(modernFamily.courses.first(where: \.isSelected))
        XCTAssertEqual(selected.id, "modern-family-s01e01")
        XCTAssertEqual(selected.completionBadge, "× 2")
        XCTAssertEqual(selected.completionAccessibilityValue, "已完成 2 次")
        XCTAssertEqual(selected.selectionAccessibilityValue, "当前课程")
    }

    @MainActor
    func testSearchTrimsAndMatchesCaseInsensitiveCourseFields() {
        let store = CourseDrawerStore()
        store.updateQuery("  bicycle THIEF  ")

        XCTAssertEqual(store.state.normalizedQuery, "bicycle thief")
        XCTAssertEqual(store.filteredCollections.map(\.id), ["modern-family-s01"])
        XCTAssertEqual(store.filteredCollections[0].courses.map(\.id), ["modern-family-s01e02"])
        XCTAssertTrue(store.state.isExpanded("modern-family-s01"))
    }

    @MainActor
    func testSearchMatchesCollectionLabelTitleAndSubtitle() {
        let store = CourseDrawerStore()

        store.updateQuery("word course")
        XCTAssertEqual(store.filteredCollections.map(\.id), ["ielts"])

        store.updateQuery("摩登家庭")
        XCTAssertEqual(store.filteredCollections.map(\.id), ["modern-family-s01"])
        XCTAssertEqual(store.filteredCollections[0].courses.count, 5)

        store.updateQuery("24 节实用口语")
        XCTAssertEqual(store.filteredCollections.map(\.id), ["voa-level-2"])

        store.updateQuery("  ")
        XCTAssertEqual(store.filteredCollections.count, 3)
    }

    @MainActor
    func testSearchCanReturnAnEmptyResult() {
        let store = CourseDrawerStore()
        store.updateQuery("definitely absent")
        XCTAssertTrue(store.filteredCollections.isEmpty)
    }

    @MainActor
    func testToggleAllowsOnlyOneExpandedCollection() {
        let store = CourseDrawerStore()
        XCTAssertTrue(store.state.isExpanded("modern-family-s01"))

        store.toggleCollection("ielts")
        XCTAssertEqual(store.state.expandedCollectionID, "ielts")
        XCTAssertFalse(store.state.isExpanded("modern-family-s01"))
        XCTAssertEqual(store.lastAction, .toggledCollection("ielts"))

        store.toggleCollection("ielts")
        XCTAssertNil(store.state.expandedCollectionID)
        XCTAssertEqual(store.lastAction, .toggledCollection(nil))

        store.toggleCollection("missing")
        XCTAssertNil(store.state.expandedCollectionID)
        XCTAssertEqual(store.lastAction, .toggledCollection(nil))
    }

    @MainActor
    func testQueryMakesEveryMatchingCollectionExpandedWithoutMutatingStoredExpansion() {
        let store = CourseDrawerStore()
        store.updateQuery("dialogue course")

        XCTAssertEqual(store.state.expandedCollectionID, "modern-family-s01")
        XCTAssertTrue(store.state.isExpanded("modern-family-s01"))
        XCTAssertTrue(store.state.isExpanded("voa-level-2"))
    }

    @MainActor
    func testPresentAndExplicitDismissReasonsAreRecorded() {
        for reason in [CourseDrawerDismissReason.header, .backdrop] {
            let store = CourseDrawerStore()
            store.present()
            XCTAssertTrue(store.state.isPresented)
            XCTAssertNil(store.state.lastDismissReason)
            XCTAssertEqual(store.lastAction, .presented)

            store.dismiss(reason: reason)
            XCTAssertFalse(store.state.isPresented)
            XCTAssertEqual(store.state.lastDismissReason, reason)
            XCTAssertEqual(store.lastAction, .dismissed(reason))
        }
    }

    @MainActor
    func testSelectionRecordsFixtureActionAndClosesWithoutMutatingCourses() {
        let store = CourseDrawerStore()
        let originalCollections = store.state.collections
        store.present()
        store.selectCourse("modern-family-s01e02")

        XCTAssertFalse(store.state.isPresented)
        XCTAssertEqual(store.state.lastDismissReason, .selection)
        XCTAssertEqual(store.lastAction, .selectedCourse("modern-family-s01e02"))
        XCTAssertEqual(store.state.collections, originalCollections)
    }

    @MainActor
    func testUnknownSelectionDoesNothing() {
        let store = CourseDrawerStore()
        store.present()
        store.selectCourse("missing")
        XCTAssertTrue(store.state.isPresented)
        XCTAssertNil(store.state.lastDismissReason)
        XCTAssertEqual(store.lastAction, .presented)
    }

    @MainActor
    func testOnlyDominantLeftDragPastThresholdDismisses() {
        let store = CourseDrawerStore()
        store.present()

        XCTAssertFalse(store.handleDrag(horizontal: -72, vertical: 0))
        XCTAssertFalse(store.handleDrag(horizontal: -90, vertical: 100))
        XCTAssertFalse(store.handleDrag(horizontal: 100, vertical: 0))
        XCTAssertTrue(store.state.isPresented)

        XCTAssertTrue(store.handleDrag(horizontal: -72.1, vertical: 20))
        XCTAssertFalse(store.state.isPresented)
        XCTAssertEqual(store.state.lastDismissReason, .swipe)
        XCTAssertEqual(store.lastAction, .dismissed(.swipe))
    }

    func testFixtureArgumentsComposeAndClampCompletion() throws {
        let state = CourseDrawerViewState.fixture(arguments: [
            "WordLoop",
            "-wordloop-course-drawer",
            "-wordloop-course-query", "Pilot",
            "-wordloop-course-collapsed",
            "-wordloop-course-completion", "-4",
        ])
        XCTAssertTrue(state.isPresented)
        XCTAssertEqual(state.query, "Pilot")
        XCTAssertNil(state.expandedCollectionID)
        let modernFamily = try XCTUnwrap(state.collections.first(where: { $0.id == "modern-family-s01" }))
        let episode2 = try XCTUnwrap(modernFamily.courses.first(where: { $0.id == "modern-family-s01e02" }))
        XCTAssertEqual(episode2.completionCount, 0)
        XCTAssertNil(episode2.completionBadge)
        XCTAssertEqual(episode2.selectionAccessibilityValue, "未选择")
    }

    func testDrawerTextAndCardBoundaryUseRealCompositedRolesAcrossEveryPalette() {
        for palette in PosterPalette.all {
            let secondaryText = palette.ink.composited(
                over: palette.background,
                opacity: WordLoopLayerOpacity.courseCardSecondaryText
            )
            let cardBoundary = palette.ink.composited(
                over: palette.background,
                opacity: WordLoopLayerOpacity.courseCardBoundary
            )
            XCTAssertGreaterThanOrEqual(secondaryText.contrastRatio(with: palette.background), 4.5, palette.id)
            XCTAssertGreaterThanOrEqual(cardBoundary.contrastRatio(with: palette.background), 3.0, palette.id)
            XCTAssertGreaterThanOrEqual(palette.accessibleAccentText.contrastRatio(with: palette.background), 4.5, palette.id)
        }
    }

    @MainActor
    func testStoreConstructsWithoutBusinessServices() {
        let store = CourseDrawerStore(state: .baseline)
        XCTAssertEqual(store.filteredCollections.count, 3)
        XCTAssertNil(store.lastAction)
    }
}
