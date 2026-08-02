import SwiftUI

public struct LiveStudyView: View {
    @Bindable private var store: StudyStore
    private let beforeStart: @Sendable () async -> Void
    private let deleteAllData: @MainActor () async throws -> Void
    @Environment(\.scenePhase) private var scenePhase
    private var copy: WordLoopCopy { .current }

    public init(
        store: StudyStore,
        beforeStart: @escaping @Sendable () async -> Void = {},
        deleteAllData: @escaping @MainActor () async throws -> Void = {}
    ) {
        self.store = store
        self.beforeStart = beforeStart
        self.deleteAllData = deleteAllData
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            MainStudyView(
                store: store.shellStore,
                courseDrawerStore: store.courseDrawerStore,
                progressDrawerStore: store.progressDrawerStore,
                completionDialogStore: store.completionDialogStore,
                actions: StudyViewActions(
                    play: { Task { await store.playCurrent() } },
                    selectMode: { mode in Task { await store.selectMode(mode) } },
                    cycleVisibility: store.cycleVisibility,
                    toggleAutoplay: { Task { await store.toggleAutoplay() } },
                    toggleRepeatPause: { Task { await store.toggleRepeatPause() } },
                    next: { Task { await store.next() } },
            markTooEasy: { Task { await store.markTooEasy() } },
            selectCourse: { courseID in Task { await store.selectCourse(courseID) } },
            downloadCourse: { courseID in Task { await store.downloadCourse(courseID) } },
                    restartCourse: { courseID in Task { await store.restartCourse(courseID) } },
                    deleteAllData: deleteAllData
                )
            )

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(copy.liveStudyPage)
                .accessibilityIdentifier("live-study.page")

            if store.state.phase == .loading {
                ProgressView()
                    .accessibilityLabel(copy.loadingCourse)
                    .accessibilityIdentifier("live-study.loading")
            } else if store.state.phase == .failed {
                Button(copy.retry) { Task { await store.retry() } }
                    .accessibilityIdentifier("live-study.retry")
            }
        }
        .task {
            await beforeStart()
            await store.start()
        }
        .onChange(of: scenePhase) { _, phase in
            Task { await store.setApplicationActive(phase == .active) }
        }
    }
}
