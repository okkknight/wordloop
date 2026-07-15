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
}
