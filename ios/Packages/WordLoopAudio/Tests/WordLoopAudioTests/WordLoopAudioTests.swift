import XCTest
@testable import WordLoopAudio

final class WordLoopAudioTests: XCTestCase {
    func testModuleIsAvailable() {
        XCTAssertEqual(WordLoopAudioModule.name, "WordLoopAudio")
    }
}
