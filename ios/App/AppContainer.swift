import Foundation
import WordLoopFeatures

@MainActor
struct AppContainer {
    let environment: AppEnvironment
    let liveStudyStore: StudyStore
    let startupCoordinator: StartupCoordinator

    static func live(bundle: Bundle = .main) -> AppContainer {
        _ = WordLoopFeaturesModule.prepareDesignSystem()
        do {
            let environment = try AppEnvironment(bundle: bundle)
            let runtime = try WordLoopFeaturesModule.makeLiveRuntime(
                apiBaseURL: environment.apiBaseURL,
                catalogURL: environment.catalogURL
            )
            return AppContainer(environment: environment, liveStudyStore: runtime.studyStore, startupCoordinator: runtime.startupCoordinator)
        } catch {
            preconditionFailure("Invalid WordLoop application configuration: \(error)")
        }
    }

    static let preview: AppContainer = {
        let environment = AppEnvironment(
            apiBaseURL: URL(string: "https://example.invalid/api")!,
            catalogURL: URL(string: "https://example.invalid/catalog.json")!,
            configurationName: "Preview"
        )
        let runtime = try! WordLoopFeaturesModule.makeLiveRuntime(
            apiBaseURL: environment.apiBaseURL,
            catalogURL: environment.catalogURL,
            inMemory: true
        )
        return AppContainer(environment: environment, liveStudyStore: runtime.studyStore, startupCoordinator: runtime.startupCoordinator)
    }()
}
