import XCTest
@testable import WordLoopNetworking

final class WordLoopNetworkingTests: XCTestCase {
    func testModuleIsAvailable() {
        XCTAssertEqual(WordLoopNetworkingModule.name, "WordLoopNetworking")
    }
}
