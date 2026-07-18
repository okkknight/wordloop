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
    static func makeLiveRuntime(apiBaseURL: URL, catalogURL: URL, inMemory: Bool = false) throws -> LiveFeatureRuntime {
        let source = try BundledCourseSource.live()
        let courseRepository = CourseRepository(source: source)
        let contentDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("WordLoopContent", isDirectory: true)
        let installations = CourseInstallationStore(fileURL: contentDirectory.appendingPathComponent("installations.json"))
        let remoteCatalog = try RemoteCatalogClient(
            url: catalogURL,
            snapshots: FileRemoteCatalogSnapshotStore(fileURL: contentDirectory.appendingPathComponent("catalog-snapshot.json"))
        )
        let downloader = CourseDownloadManager(contentRootURL: contentDirectory, installations: installations)
        let audioPlayer = try AudioPlayer.live()
        let persistence = try WordLoopProgressRuntime.make(apiBaseURL: apiBaseURL, inMemory: inMemory)
        let activeSession = ActiveStudySession()
        let realtime = try StudyRealtimeClient.live(apiBaseURL: apiBaseURL, session: activeSession)
        let coordinator = StartupCoordinator(sessions: persistence.sessionRepository, activeSession: activeSession)
        let studyStore = StudyStore(
            courses: .live(
                repository: courseRepository,
                remoteCatalog: remoteCatalog,
                installations: installations,
                installedContentRootURL: contentDirectory
            ),
            audio: .live(player: audioPlayer),
            progress: .persistent(
                repository: persistence.progressRepository,
                session: activeSession
            ),
            downloads: .live(manager: downloader, installations: installations, catalogURL: catalogURL),
            realtime: realtime,
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
