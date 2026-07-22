import SwiftUI
import WordLoopFeatures

struct RootView: View {
    let container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var startupStore: StartupStore
    @State private var studyShellStore: StudyShellStore
    @State private var courseDrawerStore: CourseDrawerStore
    @State private var progressDrawerStore: ProgressDrawerStore
    @State private var completionDialogStore: CompletionDialogStore
    @State private var liveStudyStore: StudyStore
    @State private var route: AppRoute
    @State private var startupTaskStarted = false

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
        _studyShellStore = State(
            initialValue: StudyShellStore(
                state: StudyShellViewState.fixture(arguments: ProcessInfo.processInfo.arguments)
            )
        )
        var courseState = CourseDrawerViewState.fixture(arguments: ProcessInfo.processInfo.arguments)
        let completionState = CompletionDialogViewState.fixture(arguments: ProcessInfo.processInfo.arguments)
        if completionState.isPresented { courseState.isPresented = false }
        _courseDrawerStore = State(initialValue: CourseDrawerStore(state: courseState))
        var progressState = ProgressDrawerViewState.fixture(arguments: ProcessInfo.processInfo.arguments)
        if courseState.isPresented || completionState.isPresented {
            progressState.isPresented = false
        }
        _progressDrawerStore = State(initialValue: ProgressDrawerStore(state: progressState))
        _completionDialogStore = State(initialValue: CompletionDialogStore(state: completionState))
        _liveStudyStore = State(initialValue: container.liveStudyStore)
        _route = State(initialValue: AppRouteResolver.resolve(arguments: ProcessInfo.processInfo.arguments))
    }

    var body: some View {
        Group {
            if route == .designSystemGallery {
                DesignSystemGalleryView()
            } else if route == .fixtureStudy {
                MainStudyView(
                    store: studyShellStore,
                    courseDrawerStore: courseDrawerStore,
                    progressDrawerStore: progressDrawerStore,
                    completionDialogStore: completionDialogStore
                )
            } else if route == .liveStudy {
                LiveStudyView(store: liveStudyStore) {
                    guard ProcessInfo.processInfo.arguments.contains("-wordloop-live-study") else { return }
                    if (try? await container.startupCoordinator.restore()) == nil {
                        _ = try? await container.startupCoordinator.activate(.anonymous)
                    }
                }
            } else {
                StartupView(store: startupStore) { submission in
                    Task { await activate(submission) }
                }
            }
        }
            .environment(\.dynamicTypeSize, fixtureAccessibilityText ? .accessibility3 : dynamicTypeSize)
            .task {
                guard route == .startup, !startupTaskStarted, !isStartupFixture else { return }
                startupTaskStarted = true
                await restoreStartup()
            }
    }

    private var fixtureAccessibilityText: Bool {
        ProcessInfo.processInfo.arguments.contains("-wordloop-fixture-accessibility-text")
    }

    private var isStartupFixture: Bool {
        ProcessInfo.processInfo.arguments.contains("-wordloop-startup-state") ||
        ProcessInfo.processInfo.arguments.contains("-wordloop-startup-invalid") ||
        ProcessInfo.processInfo.arguments.contains("-wordloop-ui-fresh-start")
    }

    @MainActor
    private func restoreStartup() async {
        startupStore.setRuntimeState(.restoring)
        do {
            let resolution: StartupResolution
            if let restored = try await container.startupCoordinator.restore() {
                resolution = restored
            } else {
                resolution = try await container.startupCoordinator.activate(.anonymous)
            }
            startupStore.setRuntimeState(.syncing)
            await liveStudyStore.start(preferredCourseID: resolution.preferredCourseID)
            startupStore.setRuntimeState(resolution.usedOfflineFallback ? .error : .ready)
            route = .liveStudy
        } catch {
            startupStore.setRuntimeState(.idle)
        }
    }

    @MainActor
    private func activate(_ submission: StartupSubmission) async {
        startupStore.setRuntimeState(.syncing)
        do {
            let resolution = try await container.startupCoordinator.activate(submission)
            await liveStudyStore.start(preferredCourseID: resolution.preferredCourseID)
            startupStore.setRuntimeState(resolution.usedOfflineFallback ? .error : .ready)
            route = .liveStudy
        } catch {
            startupStore.setRuntimeState(.error)
        }
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
