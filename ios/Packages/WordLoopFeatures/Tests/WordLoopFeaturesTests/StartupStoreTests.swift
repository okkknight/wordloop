import XCTest
@testable import WordLoopFeatures

final class StartupUsernameValidatorTests: XCTestCase {
    func testValidationNormalizesAnonymousAndNamedSubmissions() {
        XCTAssertEqual(StartupUsernameValidator.validate(""), .valid(.anonymous))
        XCTAssertEqual(StartupUsernameValidator.validate("   \n"), .valid(.anonymous))
        XCTAssertEqual(StartupUsernameValidator.validate(" Alice "), .valid(.named("alice")))
    }

    func testValidationRejectsEveryNonASCIIEnglishForm() {
        let rejectedInputs = ["alice1", "ali ce", "爱丽丝", "élodie", "alice!", "alice-smith"]

        for input in rejectedInputs {
            XCTAssertEqual(
                StartupUsernameValidator.validate(input),
                .invalid(message: "用户名只能使用英文字母"),
                "Expected \(input) to be rejected"
            )
        }
    }

    func testInputConstraintKeepsThirtyTwoCharactersAndDropsTheThirtyThird() {
        let thirtyTwoCharacters = String(repeating: "a", count: 32)
        XCTAssertEqual(StartupUsernameValidator.constrainedInput(thirtyTwoCharacters), thirtyTwoCharacters)
        XCTAssertEqual(
            StartupUsernameValidator.constrainedInput(thirtyTwoCharacters + "b"),
            thirtyTwoCharacters
        )
    }
}

final class StartupVisualRolesTests: XCTestCase {
    func testPlaceholderUsesTheSamePrecompositedTextRoleAsTheView() {
        XCTAssertGreaterThanOrEqual(StartupVisualRoles.placeholder.contrastRatio, 4.5)
    }

    func testInputBoundaryUsesTheSamePrecompositedControlRoleAsTheView() {
        XCTAssertGreaterThanOrEqual(StartupVisualRoles.inputBoundary.contrastRatio, 3.0)
    }
}

final class StartupStoreTests: XCTestCase {
    @MainActor
    func testStoreSubmitsAnonymousAndNormalizedNamedValues() {
        let store = StartupStore(username: "   ")
        XCTAssertEqual(store.submit(), .anonymous)
        XCTAssertEqual(store.lastSubmission, .anonymous)

        store.updateUsername(" Alice ")
        XCTAssertEqual(store.submit(), .named("alice"))
        XCTAssertEqual(store.lastSubmission, .named("alice"))
    }

    @MainActor
    func testInvalidSubmissionShowsExactMessageAndEditingClearsIt() {
        let store = StartupStore(username: "alice1")
        XCTAssertNil(store.submit())
        XCTAssertEqual(store.validationMessage, "用户名只能使用英文字母")
        XCTAssertNil(store.lastSubmission)

        store.updateUsername("alice")
        XCTAssertNil(store.validationMessage)
    }

    @MainActor
    func testStoreConstrainsInitializationUpdatesAndDirectBindings() {
        let thirtyTwoCharacters = String(repeating: "a", count: 32)
        let store = StartupStore(username: thirtyTwoCharacters + "b")
        XCTAssertEqual(store.username, thirtyTwoCharacters)

        store.updateUsername(thirtyTwoCharacters + "c")
        XCTAssertEqual(store.username, thirtyTwoCharacters)

        store.username = thirtyTwoCharacters + "d"
        XCTAssertEqual(store.username, thirtyTwoCharacters)
    }

    @MainActor
    func testBusyStatesDoNotSubmitOrReplaceTheLastSubmission() {
        let store = StartupStore(username: "Alice")
        XCTAssertEqual(store.submit(), .named("alice"))

        store.setFixtureState(.preparing)
        store.updateUsername("Bob")
        XCTAssertNil(store.submit())
        XCTAssertEqual(store.lastSubmission, .named("alice"))

        store.setFixtureState(.syncing)
        XCTAssertNil(store.submit())
        XCTAssertEqual(store.lastSubmission, .named("alice"))
    }

    func testStateCopyIsExact() {
        XCTAssertEqual(StartupState.idle.buttonTitle, "START")
        XCTAssertNil(StartupState.idle.helperText)
        XCTAssertFalse(StartupState.idle.isBusy)

        XCTAssertEqual(StartupState.preparing.buttonTitle, "PREPARING…")
        XCTAssertEqual(StartupState.preparing.helperText, "正在恢复上次课程")
        XCTAssertTrue(StartupState.preparing.isBusy)

        XCTAssertEqual(StartupState.syncing.buttonTitle, "SYNCING…")
        XCTAssertEqual(StartupState.syncing.helperText, "正在同步学习进度")
        XCTAssertTrue(StartupState.syncing.isBusy)

        XCTAssertEqual(StartupState.restoring.helperText, "正在恢复上次课程")
        XCTAssertEqual(StartupState.ready.buttonTitle, "READY")
        XCTAssertFalse(StartupState.ready.isBusy)
        XCTAssertEqual(StartupState.error.helperText, "无法同步，仍可使用本地课程")
        XCTAssertFalse(StartupState.error.isBusy)
    }

    @MainActor
    func testFixtureStoreIsConstructibleWithoutServices() {
        let store = StartupStore(
            username: "Alice",
            state: .preparing,
            validationMessage: "fixture"
        )

        XCTAssertEqual(store.username, "Alice")
        XCTAssertEqual(store.state, .preparing)
        XCTAssertEqual(store.validationMessage, "fixture")
        XCTAssertNil(store.lastSubmission)
    }
}
