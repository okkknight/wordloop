import Foundation
import WordLoopAudio
import WordLoopContent
import WordLoopProgress

public struct LiveFeatureRuntime {
    public let studyStore: StudyStore
    public let startupCoordinator: StartupCoordinator
}

public extension WordLoopFeaturesModule {
    @MainActor
    static func makeLiveRuntime(apiBaseURL: URL, inMemory: Bool = false) throws -> LiveFeatureRuntime {
        let source = try BundledCourseSource.live()
        let courseRepository = CourseRepository(source: source)
        let audioPlayer = try AudioPlayer.live()
        let persistence = try WordLoopProgressRuntime.make(apiBaseURL: apiBaseURL, inMemory: inMemory)
        let activeSession = ActiveStudySession()
        let completionFallback = TemporaryProgressRepository()
        let coordinator = StartupCoordinator(sessions: persistence.sessionRepository, activeSession: activeSession)
        let studyStore = StudyStore(
            courses: .live(repository: courseRepository),
            audio: .live(player: audioPlayer),
            progress: .persistent(
                repository: persistence.progressRepository,
                session: activeSession,
                completionFallback: completionFallback
            ),
            courseSelection: { courseID, mode in
                guard let userID = await activeSession.userID else { return }
                try? await persistence.sessionRepository.publishRecentCourse(
                    userID: userID, mode: mode, courseID: courseID
                )
            }
        )
        return LiveFeatureRuntime(studyStore: studyStore, startupCoordinator: coordinator)
    }
}
