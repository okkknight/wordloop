import XCTest
@testable import WordLoop

final class AppIntegrationTests: XCTestCase {
    func testEnvironmentReadsBuildSettingValues() throws {
        let environment = try AppEnvironment(infoDictionary: [
            "WordLoopAPIBaseURL": "https://example.com/api",
            "WordLoopCatalogURL": "https://example.com/catalog.json",
            "WordLoopConfigurationName": "Test",
        ])

        XCTAssertEqual(environment.apiBaseURL.absoluteString, "https://example.com/api")
        XCTAssertEqual(environment.catalogURL.absoluteString, "https://example.com/catalog.json")
        XCTAssertEqual(environment.configurationName, "Test")
    }
}
