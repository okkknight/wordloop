import Foundation
import WordLoopNetworking

public struct WordLoopProgressRuntime: Sendable {
    public let progressRepository: PersistentProgressRepository
    public let sessionRepository: StudySessionRepository

    public static func make(apiBaseURL: URL, inMemory: Bool = false) throws -> Self {
        let container = try inMemory
            ? WordLoopProgressContainer.makeInMemory()
            : WordLoopProgressContainer.makePersistent()
        let api = try ProgressAPIClient(baseURL: apiBaseURL)
        return Self(
            progressRepository: PersistentProgressRepository(container: container, api: api),
            sessionRepository: StudySessionRepository(container: container, api: api)
        )
    }
}
