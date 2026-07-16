import XCTest
import WordLoopContent
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

    func testBundledContentResourcesResolveInsideTheBuiltApp() throws {
        let source = try BundledCourseSource.live()
        let catalog = try source.loadCatalog()
        XCTAssertEqual(catalog.courses.count, 30)
        XCTAssertEqual(catalog.defaultCourseID.rawValue, "modern-family-s01e01")

        let descriptor = try XCTUnwrap(catalog.courses.first { $0.id == catalog.defaultCourseID })
        let course = try source.loadCourse(descriptor: descriptor)
        XCTAssertEqual(course.entries.count, 91)
        let audioURL = try XCTUnwrap(course.entries.first?.audioURL)
        XCTAssertTrue(audioURL.isFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path))
    }
}
