import SwiftUI

public struct LiveStudyView: View {
    @Bindable private var store: StudyStore
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StudyStore) {
        self.store = store
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
                    toggleRepeatPause: {},
                    next: { Task { await store.next() } },
                    markTooEasy: { Task { await store.markTooEasy() } },
                    selectCourse: { courseID in Task { await store.selectCourse(courseID) } }
                )
            )

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("真实学习页")
                .accessibilityIdentifier("live-study.page")

            if store.state.phase == .loading {
                ProgressView()
                    .accessibilityLabel("正在加载课程")
                    .accessibilityIdentifier("live-study.loading")
            } else if store.state.phase == .failed {
                Button("重试") { Task { await store.start() } }
                    .accessibilityIdentifier("live-study.retry")
            }
        }
        .task { await store.start() }
        .onChange(of: scenePhase) { _, phase in
            Task { await store.setApplicationActive(phase == .active) }
        }
    }
}
