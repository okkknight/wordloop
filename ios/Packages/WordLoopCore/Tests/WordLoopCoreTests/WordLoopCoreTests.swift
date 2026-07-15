import XCTest
@testable import WordLoopCore

final class WordLoopCoreTests: XCTestCase {
    func testModuleIsAvailable() {
        XCTAssertEqual(WordLoopCoreModule.name, "WordLoopCore")
    }
}
