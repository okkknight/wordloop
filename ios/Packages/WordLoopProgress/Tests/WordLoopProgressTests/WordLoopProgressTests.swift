import XCTest
@testable import WordLoopProgress

final class WordLoopProgressTests: XCTestCase {
    func testModuleIsAvailable() {
        XCTAssertEqual(WordLoopProgressModule.name, "WordLoopProgress")
    }
}
