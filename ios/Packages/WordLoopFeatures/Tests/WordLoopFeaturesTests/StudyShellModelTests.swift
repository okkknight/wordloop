import XCTest
import WordLoopDesignSystem
@testable import WordLoopFeatures

final class StudyShellModelTests: XCTestCase {
    func testSentenceAndWordVisibilityCyclesAreDeterministic() {
        XCTAssertEqual(StudyTextVisibility.full.next(for: .sentence), .focus)
        XCTAssertEqual(StudyTextVisibility.focus.next(for: .sentence), .hidden)
        XCTAssertEqual(StudyTextVisibility.hidden.next(for: .sentence), .full)

        XCTAssertEqual(StudyTextVisibility.full.next(for: .word), .hidden)
        XCTAssertEqual(StudyTextVisibility.focus.next(for: .word), .hidden)
        XCTAssertEqual(StudyTextVisibility.hidden.next(for: .word), .full)
        XCTAssertEqual(StudyTextVisibility.hidden.accessibilityValue, "学习内容已隐藏")
    }

    func testHighlightRangesPreserveRepeatedTokensAndPunctuation() {
        let text = "Wait, wait, wait."
        let ranges = StudyShellItem.highlightRanges(matching: "wait", in: text)
        let item = StudyShellItem(
            id: "repeat",
            kind: .sentence,
            english: text,
            translation: "等等",
            highlightRanges: ranges
        )

        XCTAssertEqual(ranges, [.init(6, 10), .init(12, 16)])
        XCTAssertEqual(
            item.resolvedHighlightRanges().map { String(text[$0]) },
            ["wait", "wait"]
        )
        XCTAssertEqual(
            item.textSegments(),
            [
                .init(text: "Wait, ", isHighlighted: false),
                .init(text: "wait", isHighlighted: true),
                .init(text: ", ", isHighlighted: false),
                .init(text: "wait", isHighlighted: true),
                .init(text: ".", isHighlighted: false),
            ]
        )

        let punctuation = StudyShellItem.highlightRanges(matching: "wait,", in: text)
        XCTAssertEqual(punctuation, [.init(6, 11)])
    }

    func testInvalidHighlightRangeSetFailsClosed() {
        let invalidSets: [[StudyHighlightRange]] = [
            [.init(-1, 2)],
            [.init(2, 2)],
            [.init(2, 99)],
            [.init(3, 5), .init(1, 2)],
            [.init(1, 4), .init(3, 5)],
        ]

        for ranges in invalidSets {
            let item = StudyShellItem(
                id: "invalid",
                kind: .sentence,
                english: "hello",
                translation: "你好",
                highlightRanges: ranges
            )
            XCTAssertTrue(item.resolvedHighlightRanges().isEmpty)
            XCTAssertEqual(item.textSegments(), [.init(text: "hello", isHighlighted: false)])
        }
    }

    func testBaselineAndWordFixturesMatchLockedProductCopy() {
        let baseline = StudyShellViewState.baselineSentence
        XCTAssertEqual(baseline.palette.id, "sun")
        XCTAssertEqual(baseline.courseLabel, "MODERN FAMILY · S01E01")
        XCTAssertEqual(baseline.progressLabel, "75/91")
        XCTAssertEqual(baseline.item.english, "Uh, my dad still isn't completely comfortable with this.")
        XCTAssertEqual(baseline.item.translation, "我爸对这事还是不太习惯")
        XCTAssertEqual(baseline.item.resolvedHighlightRanges().map { String(baseline.item.english[$0]) }, ["completely comfortable"])

        XCTAssertEqual(StudyShellViewState.word.item.kind, .word)
        XCTAssertNotNil(StudyShellViewState.word.item.phonetic)
        XCTAssertGreaterThanOrEqual(StudyShellViewState.longWord.item.english.count, 12)
    }

    func testFixtureArgumentsComposeAndClampMastery() {
        let fixture = StudyShellViewState.fixture(arguments: [
            "WordLoop",
            "-wordloop-study-item", "long-word",
            "-wordloop-study-mode", "listen",
            "-wordloop-study-visibility", "hidden",
            "-wordloop-study-palette", "night",
            "-wordloop-study-mastery", "99",
            "-wordloop-study-autoplay", "true",
        ])

        XCTAssertEqual(fixture.item, StudyShellViewState.longWord.item)
        XCTAssertEqual(fixture.mode, .listen)
        XCTAssertEqual(fixture.visibility, .hidden)
        XCTAssertEqual(fixture.palette.id, "night")
        XCTAssertEqual(fixture.masteryCount, 3)
        XCTAssertTrue(fixture.isAutoplayEnabled)
        XCTAssertTrue(fixture.isTooEasyDisabled)
        XCTAssertTrue(fixture.isPauseDisabled)
        XCTAssertFalse(fixture.isAutoplayDisabled)

        var lowerBound = StudyShellViewState.baselineSentence
        lowerBound.masteryCount = -10
        XCTAssertEqual(lowerBound.masteryCount, 0)
    }

    func testUnknownPaletteFailsClosedToSun() {
        let fixture = StudyShellViewState.fixture(arguments: [
            "WordLoop", "-wordloop-study-palette", "missing",
        ])
        XCTAssertEqual(fixture.palette.id, "sun")
    }

    func testWordFixtureRejectsSentenceOnlyFocusVisibility() {
        let fixture = StudyShellViewState.fixture(arguments: [
            "WordLoop",
            "-wordloop-study-item", "word",
            "-wordloop-study-visibility", "focus",
        ])
        XCTAssertEqual(fixture.visibility, .full)
    }

    func testSunSemanticTextAndControlRolesMeetContrastThresholds() throws {
        let sun = try XCTUnwrap(PosterPalette.all.first(where: { $0.id == "sun" }))
        XCTAssertGreaterThanOrEqual(sun.ink.contrastRatio(with: sun.background), 4.5)
        XCTAssertGreaterThanOrEqual(sun.accessibleAccentText.contrastRatio(with: sun.background), 4.5)
        XCTAssertGreaterThanOrEqual(sun.ink.contrastRatio(with: sun.background), 3.0)
    }
}

final class StudyShellStoreTests: XCTestCase {
    @MainActor
    func testModeVisibilityAndLocalPresentationTogglesRecordActions() {
        let store = StudyShellStore()

        store.selectMode(.listen)
        XCTAssertEqual(store.state.mode, .listen)
        XCTAssertEqual(store.lastAction, .selectedMode(.listen))

        store.cycleVisibility()
        XCTAssertEqual(store.state.visibility, .focus)
        XCTAssertEqual(store.lastAction, .cycledVisibility(.focus))

        store.toggleAutoplay()
        XCTAssertTrue(store.state.isAutoplayEnabled)
        XCTAssertEqual(store.lastAction, .toggledAutoplay(true))

        store.selectMode(.repeat)
        store.togglePause()
        XCTAssertTrue(store.state.isRepeatPaused)
        XCTAssertEqual(store.lastAction, .toggledPause(true))
    }

    @MainActor
    func testControlsDoNotSimulateBusinessProgress() {
        let store = StudyShellStore()
        let initialState = store.state

        store.next()
        XCTAssertEqual(store.lastAction, .next)
        XCTAssertEqual(store.state, initialState)

        store.markTooEasy()
        XCTAssertEqual(store.lastAction, .markedTooEasy)
        XCTAssertEqual(store.state, initialState)
    }

    @MainActor
    func testDisabledFixtureControlsIgnoreActions() {
        var state = StudyShellViewState.baselineSentence
        state.mode = .repeat
        state.masteryCount = 3
        let store = StudyShellStore(state: state)

        store.toggleAutoplay()
        XCTAssertNil(store.lastAction)
        store.markTooEasy()
        XCTAssertNil(store.lastAction)

        store.selectMode(.listen)
        store.togglePause()
        XCTAssertEqual(store.lastAction, .selectedMode(.listen))
        XCTAssertFalse(store.state.isRepeatPaused)
    }

    @MainActor
    func testWordFixtureUsesTwoStepVisibilityCycle() {
        let store = StudyShellStore(state: .word)
        store.cycleVisibility()
        XCTAssertEqual(store.state.visibility, .hidden)
        store.cycleVisibility()
        XCTAssertEqual(store.state.visibility, .full)
    }

    @MainActor
    func testStoreConstructsWithoutBusinessServices() {
        let store = StudyShellStore(state: .longWord)
        XCTAssertEqual(store.state.item.kind, .word)
        XCTAssertNil(store.lastAction)
    }
}
