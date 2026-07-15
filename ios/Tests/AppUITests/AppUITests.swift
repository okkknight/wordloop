import XCTest

@MainActor
final class AppUITests: XCTestCase {
    func testAppLaunchesIntoStartupPage() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["startup.page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["startup.username"].exists)
        XCTAssertTrue(app.buttons["startup.submit"].exists)
        XCTAssertEqual(app.buttons["startup.submit"].label, "START")
        XCTAssertFalse(app.descendants(matching: .any)["design-system.gallery"].exists)
    }

    func testStartupAcceptsAnonymousAndNormalizedNamedSubmissions() {
        let anonymousApp = XCUIApplication()
        anonymousApp.launch()
        anonymousApp.buttons["startup.submit"].tap()
        XCTAssertEqual(anonymousApp.buttons["startup.submit"].value as? String, "已提交匿名用户")

        anonymousApp.terminate()

        let namedApp = XCUIApplication()
        namedApp.launch()
        let username = namedApp.textFields["startup.username"]
        username.tap()
        username.typeText(" Alice ")
        namedApp.keyboards.buttons["Go"].tap()
        XCTAssertEqual(namedApp.buttons["startup.submit"].value as? String, "已提交用户 alice")
    }

    func testStartupValidationClearsWhenEditing() {
        let app = XCUIApplication()
        app.launch()

        let username = app.textFields["startup.username"]
        username.tap()
        username.typeText("Word1")
        app.buttons["startup.submit"].tap()
        XCTAssertTrue(app.staticTexts["startup.error"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["startup.error"].label, "用户名只能使用英文字母")

        username.tap()
        username.typeText("a")
        XCTAssertFalse(app.staticTexts["startup.error"].exists)
        XCTAssertTrue(app.buttons["startup.submit"].isHittable)
    }

    func testStartupBusyFixturesExposeExactCopyAndDisabledButton() {
        for fixture in [
            (state: "preparing", button: "PREPARING…", helper: "正在恢复上次课程"),
            (state: "syncing", button: "SYNCING…", helper: "正在同步学习进度"),
        ] {
            let app = XCUIApplication()
            app.launchArguments = ["-wordloop-startup-state", fixture.state]
            app.launch()

            XCTAssertTrue(app.buttons["startup.submit"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.buttons["startup.submit"].label, fixture.button)
            XCTAssertFalse(app.buttons["startup.submit"].isEnabled)
            XCTAssertEqual(app.staticTexts["startup.helper"].label, fixture.helper)
            app.terminate()
        }
    }

    func testDesignSystemGalleryRemainsAvailableByLaunchArgument() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-design-system-gallery"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["design-system.gallery"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "design-system.palette.paper").count, 1)
        XCTAssertTrue(app.buttons["Show fixture dialog"].exists)
    }

    func testFixtureDialogAndDrawerAreAccessible() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-design-system-gallery"]
        app.launch()

        app.buttons["Show fixture dialog"].tap()
        XCTAssertTrue(app.buttons["CANCEL"].waitForExistence(timeout: 2))
        app.buttons["CANCEL"].tap()

        app.buttons["Show fixture drawer"].tap()
        XCTAssertTrue(app.buttons["Close fixture drawer"].waitForExistence(timeout: 2))
        app.buttons["Close fixture drawer"].tap()
    }

    func testAccessibilityTextAndReduceMotionFixtureLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-design-system-gallery", "-wordloop-fixture-accessibility-text", "-wordloop-fixture-reduce-motion"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["design-system.gallery"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Native fixture gallery"].exists)
    }

    func testStartupAccessibilityTextAndReduceMotionFixtureLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-startup-invalid", "-wordloop-fixture-accessibility-text", "-wordloop-fixture-reduce-motion"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["startup.page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["startup.error"].exists)
        XCTAssertTrue(app.buttons["startup.submit"].isHittable)
    }

    func testStudyShellRequiresExplicitLaunchArgumentAndKeepsFixturePriority() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-study-shell"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["study.page"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["startup.page"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["design-system.gallery"].exists)
        app.terminate()

        let galleryApp = XCUIApplication()
        galleryApp.launchArguments = ["-wordloop-study-shell", "-wordloop-design-system-gallery"]
        galleryApp.launch()
        XCTAssertTrue(galleryApp.descendants(matching: .any)["design-system.gallery"].waitForExistence(timeout: 5))
        XCTAssertFalse(galleryApp.descendants(matching: .any)["study.page"].exists)
    }

    func testStudyShellBaselineContentAndSafeAreaControlsAreAccessible() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-study-shell"]
        app.launch()

        XCTAssertTrue(app.buttons["study.course"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["study.progress"].isHittable)
        XCTAssertEqual(app.staticTexts["study.course-context"].label, "MODERN FAMILY · S01E01")
        XCTAssertEqual(app.staticTexts["study.progress-count"].label, "第 75 条，共 91 条")
        XCTAssertEqual(app.staticTexts["study.english"].label, "Uh, my dad still isn't completely comfortable with this.")
        XCTAssertEqual(app.staticTexts["study.translation"].label, "我爸对这事还是不太习惯")
        XCTAssertTrue(app.buttons["study.mastery"].isHittable)
        XCTAssertTrue(app.buttons["study.too-easy"].isHittable)
        XCTAssertTrue(app.buttons["study.primary-control"].isHittable)
        XCTAssertTrue(app.buttons["study.next"].isHittable)

        for identifier in ["study.course", "study.progress", "study.mastery", "study.too-easy", "study.primary-control", "study.next"] {
            let frame = app.descendants(matching: .any)[identifier].frame
            XCTAssertGreaterThanOrEqual(frame.minX, 0)
            XCTAssertLessThanOrEqual(frame.maxX, app.frame.maxX)
        }
    }

    func testStudyShellModeVisibilityAndWordFixturesStayDeterministic() {
        let listenApp = XCUIApplication()
        listenApp.launchArguments = ["-wordloop-study-shell", "-wordloop-study-mode", "listen"]
        listenApp.launch()
        XCTAssertEqual(listenApp.buttons["study.mode.listen"].value as? String, "Selected")
        XCTAssertEqual(listenApp.buttons["study.primary-control"].label, "AUTOPLAY")
        listenApp.buttons["study.primary-control"].tap()
        XCTAssertEqual(listenApp.buttons["study.primary-control"].label, "AUTOPLAY ON")
        listenApp.terminate()

        let repeatApp = XCUIApplication()
        repeatApp.launchArguments = ["-wordloop-study-shell", "-wordloop-study-mode", "repeat"]
        repeatApp.launch()
        XCTAssertEqual(repeatApp.buttons["study.mode.repeat"].value as? String, "Selected")
        XCTAssertEqual(repeatApp.buttons["study.primary-control"].label, "PAUSE")
        XCTAssertTrue(repeatApp.descendants(matching: .any)["study.repeat-card"].exists)
        repeatApp.buttons["study.primary-control"].tap()
        XCTAssertEqual(repeatApp.buttons["study.primary-control"].label, "RESUME")
        repeatApp.terminate()

        let wordApp = XCUIApplication()
        wordApp.launchArguments = ["-wordloop-study-shell", "-wordloop-study-item", "word"]
        wordApp.launch()
        XCTAssertTrue(wordApp.staticTexts["study.phonetic"].waitForExistence(timeout: 5))
        wordApp.buttons["study.visibility"].tap()
        XCTAssertFalse(wordApp.staticTexts["study.english"].exists)
        XCTAssertTrue(wordApp.staticTexts["study.hidden-copy"].exists)
        wordApp.buttons["study.visibility"].tap()
        XCTAssertTrue(wordApp.staticTexts["study.english"].exists)
    }

    func testStudyShellAccessibilityFixtureKeepsWorstCaseContentReachable() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-wordloop-study-shell",
            "-wordloop-study-item", "long-word",
            "-wordloop-fixture-accessibility-text",
            "-wordloop-fixture-reduce-motion",
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["study.page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["study.english"].exists)
        let playButton = app.buttons["study.play"]
        let visibilityButton = app.buttons["study.visibility"]
        XCTAssertTrue(playButton.isHittable)
        XCTAssertTrue(visibilityButton.isHittable)
        XCTAssertGreaterThanOrEqual(playButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(playButton.frame.height, 44)
        XCTAssertLessThanOrEqual(playButton.frame.maxX, visibilityButton.frame.minX)
        let nextButton = app.buttons["study.next"]
        XCTAssertTrue(nextButton.exists)
        if !nextButton.isHittable { app.swipeUp() }
        if !nextButton.isHittable { app.swipeUp() }
        XCTAssertTrue(nextButton.isHittable)
    }
}
