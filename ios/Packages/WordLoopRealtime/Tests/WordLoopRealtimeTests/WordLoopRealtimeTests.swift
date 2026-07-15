import XCTest
@testable import WordLoopRealtime

final class WordLoopRealtimeTests: XCTestCase {
    func testModuleIsAvailable() {
        XCTAssertEqual(WordLoopRealtimeModule.name, "WordLoopRealtime")
    }
}
