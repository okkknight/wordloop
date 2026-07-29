import XCTest
@testable import WordLoopFeatures

final class WordLoopFeaturesTests: XCTestCase {
    func testModuleIsAvailable() {
        XCTAssertEqual(WordLoopFeaturesModule.name, "WordLoopFeatures")
    }

    @MainActor
    func testDesignSystemGalleryIsConstructibleWithoutServices() {
        _ = DesignSystemGalleryView()
    }
}
