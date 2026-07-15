import XCTest

@MainActor
final class AppUITests: XCTestCase {
    func testAppLaunchesIntoDesignSystemGallery() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["design-system.gallery"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "design-system.palette.paper").count, 1)
        XCTAssertTrue(app.buttons["Show fixture dialog"].exists)
    }

    func testFixtureDialogAndDrawerAreAccessible() {
        let app = XCUIApplication()
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
        app.launchArguments = ["-wordloop-fixture-accessibility-text", "-wordloop-fixture-reduce-motion"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["design-system.gallery"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Native fixture gallery"].exists)
    }
}
