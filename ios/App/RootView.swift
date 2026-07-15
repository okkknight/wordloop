import SwiftUI
import WordLoopFeatures

struct RootView: View {
    let container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var startupStore: StartupStore

    init(container: AppContainer) {
        self.container = container
        let fixture = StartupLaunchFixture(arguments: ProcessInfo.processInfo.arguments)
        _startupStore = State(
            initialValue: StartupStore(
                username: fixture.username,
                state: fixture.state,
                validationMessage: fixture.validationMessage
            )
        )
    }

    var body: some View {
        Group {
            if showsDesignSystemGallery {
                DesignSystemGalleryView()
            } else {
                StartupView(store: startupStore)
            }
        }
            .environment(\.dynamicTypeSize, fixtureAccessibilityText ? .accessibility3 : dynamicTypeSize)
    }

    private var showsDesignSystemGallery: Bool {
        ProcessInfo.processInfo.arguments.contains("-wordloop-design-system-gallery")
    }

    private var fixtureAccessibilityText: Bool {
        ProcessInfo.processInfo.arguments.contains("-wordloop-fixture-accessibility-text")
    }

}

private struct StartupLaunchFixture {
    let username: String
    let state: StartupState
    let validationMessage: String?

    init(arguments: [String]) {
        if arguments.contains("-wordloop-startup-invalid") {
            username = "Word1"
            state = .idle
            validationMessage = StartupUsernameValidator.invalidUsernameMessage
            return
        }

        username = ""
        validationMessage = nil
        guard let flagIndex = arguments.firstIndex(of: "-wordloop-startup-state"),
              arguments.indices.contains(flagIndex + 1),
              let fixtureState = StartupState(rawValue: arguments[flagIndex + 1]) else {
            state = .idle
            return
        }
        state = fixtureState
    }
}

#Preview {
    RootView(container: .preview)
}
