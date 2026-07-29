import XCTest
@testable import WordLoopFeatures

final class CompletionDialogModelTests: XCTestCase {
    func testRestartCompletedCourseCopyIsExact() {
        let kind = CompletionDialogKind.restartCompletedCourse
        XCTAssertEqual(kind.kicker, "COURSE COMPLETE")
        XCTAssertEqual(kind.title, "这门课程已经完成")
        XCTAssertEqual(kind.message, "要重新开始练习吗？现有练习进度将被清零。")
        XCTAssertEqual(kind.cancelTitle, "取消")
        XCTAssertEqual(kind.confirmTitle, "重新开始")
        XCTAssertEqual(kind.accessibilityLabel, "COURSE COMPLETE，这门课程已经完成，要重新开始练习吗？现有练习进度将被清零。")
    }

    func testNaturalCompletionCopyIsExact() {
        let kind = CompletionDialogKind.courseCompleted
        XCTAssertEqual(kind.kicker, "COURSE COMPLETE")
        XCTAssertEqual(kind.title, "这门课程学完了")
        XCTAssertEqual(kind.message, "太棒了。你可以从头再练一遍，或者挑选下一门课程继续学习。")
        XCTAssertEqual(kind.cancelTitle, "选择课程")
        XCTAssertEqual(kind.confirmTitle, "再练一次")
    }

    func testFixtureParsesBothKindsAndFixedError() {
        let restart = CompletionDialogViewState.fixture(arguments: [
            "WordLoop", "-wordloop-completion-dialog", "restart",
        ])
        XCTAssertTrue(restart.isPresented)
        XCTAssertEqual(restart.kind, .restartCompletedCourse)
        XCTAssertEqual(restart.courseID, "modern-family-s01e01")
        XCTAssertNil(restart.errorMessage)

        let complete = CompletionDialogViewState.fixture(arguments: [
            "WordLoop", "-wordloop-completion-dialog", "COMPLETE", "-wordloop-completion-error",
        ])
        XCTAssertTrue(complete.isPresented)
        XCTAssertEqual(complete.kind, .courseCompleted)
        XCTAssertEqual(complete.courseID, "modern-family-s01e01")
        XCTAssertEqual(complete.errorMessage, "暂时无法重置进度，请稍后重试。")
    }

    func testMissingEmptyAndInvalidFixtureFailClosed() {
        for arguments in [
            ["WordLoop"],
            ["WordLoop", "-wordloop-completion-dialog"],
            ["WordLoop", "-wordloop-completion-dialog", ""],
            ["WordLoop", "-wordloop-completion-dialog", "unknown"],
        ] {
            let state = CompletionDialogViewState.fixture(arguments: arguments)
            XCTAssertFalse(state.isPresented)
            XCTAssertEqual(state.kind, .restartCompletedCourse)
            XCTAssertEqual(state.courseID, CompletionDialogViewState.fixtureCourseID)
            XCTAssertNil(state.errorMessage)
        }
    }

    func testOnlyFixedErrorMessageIsAccepted() {
        var state = CompletionDialogViewState(
            kind: .courseCompleted,
            errorMessage: "network failed",
            isPresented: true
        )
        XCTAssertNil(state.errorMessage)
        state.errorMessage = CompletionDialogViewState.fixedErrorMessage
        XCTAssertEqual(state.errorMessage, CompletionDialogViewState.fixedErrorMessage)
        state.errorMessage = ""
        XCTAssertNil(state.errorMessage)
    }

    @MainActor
    func testCancelChooseAndRestartRecordOnlyPresentationIntents() {
        let cancelStore = CompletionDialogStore()
        cancelStore.present(kind: .restartCompletedCourse)
        XCTAssertEqual(cancelStore.lastAction, .presented(.restartCompletedCourse))
        cancelStore.cancel()
        XCTAssertFalse(cancelStore.state.isPresented)
        XCTAssertEqual(cancelStore.lastAction, .cancelled)

        let chooseStore = CompletionDialogStore(
            state: .init(kind: .courseCompleted, isPresented: true)
        )
        chooseStore.chooseCourse()
        XCTAssertFalse(chooseStore.state.isPresented)
        XCTAssertEqual(chooseStore.lastAction, .selectedCourse)

        let restartStore = CompletionDialogStore(
            state: .init(kind: .courseCompleted, courseID: "modern-family-s01e01", isPresented: true)
        )
        restartStore.requestRestart()
        XCTAssertFalse(restartStore.state.isPresented)
        XCTAssertEqual(restartStore.lastAction, .requestedRestart("modern-family-s01e01"))
    }

    @MainActor
    func testRestartIntentDoesNotMutateExistingFeatureSnapshots() {
        let studyStore = StudyShellStore(state: .baselineSentence)
        let courseStore = CourseDrawerStore(state: .baseline)
        let progressStore = ProgressDrawerStore(state: .mixed)
        let studySnapshot = studyStore.state
        let courseSnapshot = courseStore.state
        let progressSnapshot = progressStore.state

        let completionStore = CompletionDialogStore(
            state: .init(kind: .restartCompletedCourse, isPresented: true)
        )
        completionStore.requestRestart()

        XCTAssertEqual(completionStore.lastAction, .requestedRestart("modern-family-s01e01"))
        XCTAssertEqual(studyStore.state, studySnapshot)
        XCTAssertEqual(courseStore.state, courseSnapshot)
        XCTAssertEqual(progressStore.state, progressSnapshot)
    }

    @MainActor
    func testHiddenStoreIgnoresActionsAndEmptyCourseCannotRequestRestart() {
        let hidden = CompletionDialogStore()
        hidden.cancel()
        hidden.chooseCourse()
        hidden.requestRestart()
        XCTAssertNil(hidden.lastAction)

        let emptyCourse = CompletionDialogStore(
            state: .init(kind: .courseCompleted, courseID: "", isPresented: true)
        )
        emptyCourse.requestRestart()
        XCTAssertTrue(emptyCourse.state.isPresented)
        XCTAssertNil(emptyCourse.lastAction)
    }

    @MainActor
    func testStoreConstructsWithoutBusinessServices() {
        let store = CompletionDialogStore(
            state: .fixture(arguments: ["WordLoop", "-wordloop-completion-dialog", "complete"])
        )
        XCTAssertTrue(store.state.isPresented)
        XCTAssertNil(store.lastAction)
    }
}
