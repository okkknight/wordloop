import Foundation
import WordLoopFeatures

@MainActor
struct AppContainer {
    let environment: AppEnvironment
    let liveStudyStore: StudyStore

    static func live(bundle: Bundle = .main) -> AppContainer {
        _ = WordLoopFeaturesModule.prepareDesignSystem()
        do {
            return AppContainer(
                environment: try AppEnvironment(bundle: bundle),
                liveStudyStore: try WordLoopFeaturesModule.makeLiveStudyStore()
            )
        } catch {
            preconditionFailure("Invalid WordLoop application configuration: \(error)")
        }
    }

    static let preview = AppContainer(
        environment: AppEnvironment(
            apiBaseURL: URL(string: "https://example.invalid/api")!,
            catalogURL: URL(string: "https://example.invalid/catalog.json")!,
            configurationName: "Preview"
        ),
        liveStudyStore: try! WordLoopFeaturesModule.makeLiveStudyStore()
    )
}
