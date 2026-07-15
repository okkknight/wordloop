import XCTest
@testable import WordLoopContent

final class WordLoopContentTests: XCTestCase {
    func testModuleIsAvailable() {
        XCTAssertEqual(WordLoopContentModule.name, "WordLoopContent")
    }
}
