import Foundation
import XCTest
@testable import WordLoopCore

final class RepeatScorerGoldenTests: XCTestCase {
    func testSwiftScorerMatchesSharedWebGoldenFixtures() throws {
        let fixturesURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "tests/fixtures/repeat-scoring.json")
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: fixturesURL))
        XCTAssertEqual(fixtures.count, 10)
        for fixture in fixtures {
            let actual = RepeatScorer.score(
                target: fixture.target, transcript: fixture.transcript, sentence: fixture.sentence
            )
            XCTAssertEqual(actual.passed, fixture.expected.passed, fixture.id)
            XCTAssertEqual(actual.score, fixture.expected.score, fixture.id)
            XCTAssertEqual(actual.matched, fixture.expected.matched, fixture.id)
        }
    }
}

private struct Fixture: Decodable {
    let id: String
    let target: String
    let transcript: String
    let sentence: Bool
    let expected: Expected
}

private struct Expected: Decodable {
    let passed: Bool
    let score: Int
    let matched: String
}
