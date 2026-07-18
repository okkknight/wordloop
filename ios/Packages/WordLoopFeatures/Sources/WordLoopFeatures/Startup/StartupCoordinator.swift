import WordLoopCore
import WordLoopProgress

public struct StartupResolution: Equatable, Sendable {
    public let preferredCourseID: CourseID?
    public let usedOfflineFallback: Bool
}

public actor StartupCoordinator {
    private let sessions: StudySessionRepository
    private let activeSession: ActiveStudySession

    init(sessions: StudySessionRepository, activeSession: ActiveStudySession) {
        self.sessions = sessions
        self.activeSession = activeSession
    }

    public func restore() async throws -> StartupResolution? {
        guard let local = try await sessions.restore() else { return nil }
        await activeSession.activate(local.userID)
        do {
            let remote = try await sessions.syncRecentCourse(userID: local.userID, mode: .repeat)
            return StartupResolution(preferredCourseID: remote ?? local.recentCourseID, usedOfflineFallback: false)
        } catch {
            return StartupResolution(preferredCourseID: local.recentCourseID, usedOfflineFallback: true)
        }
    }

    public func activate(_ submission: StartupSubmission) async throws -> StartupResolution {
        let username: String? = if case let .named(value) = submission { value } else { nil }
        let local = try await sessions.activate(username: username)
        await activeSession.activate(local.userID)
        do {
            let remote = try await sessions.syncRecentCourse(userID: local.userID, mode: .repeat)
            return StartupResolution(preferredCourseID: remote ?? local.recentCourseID, usedOfflineFallback: false)
        } catch {
            return StartupResolution(preferredCourseID: local.recentCourseID, usedOfflineFallback: true)
        }
    }
}
