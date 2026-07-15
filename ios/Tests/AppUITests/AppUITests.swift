import XCTest

@MainActor
final class AppUITests: XCTestCase {
    func testAppLaunchesIntoSkeleton() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["wordloop.root.skeleton"]
                .waitForExistence(timeout: 5)
        )
    }
}
