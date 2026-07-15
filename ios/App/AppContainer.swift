import Foundation
import WordLoopFeatures

struct AppContainer: Sendable {
    let environment: AppEnvironment

    static func live(bundle: Bundle = .main) -> AppContainer {
        _ = WordLoopFeaturesModule.prepareDesignSystem()
        do {
            return AppContainer(environment: try AppEnvironment(bundle: bundle))
        } catch {
            preconditionFailure("Invalid WordLoop application configuration: \(error)")
        }
    }

    static let preview = AppContainer(
        environment: AppEnvironment(
            apiBaseURL: URL(string: "https://example.invalid/api")!,
            catalogURL: URL(string: "https://example.invalid/catalog.json")!,
            configurationName: "Preview"
        )
    )
}
