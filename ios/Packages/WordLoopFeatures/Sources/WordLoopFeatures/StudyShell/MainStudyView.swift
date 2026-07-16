import SwiftUI
import WordLoopDesignSystem

@MainActor
struct StudyViewActions {
    var play: @MainActor () -> Void
    var selectMode: @MainActor (StudyShellMode) -> Void
    var cycleVisibility: @MainActor () -> Void
    var toggleAutoplay: @MainActor () -> Void
    var toggleRepeatPause: @MainActor () -> Void
    var next: @MainActor () -> Void
    var markTooEasy: @MainActor () -> Void
    var selectCourse: @MainActor (String) -> Void
    var restartCourse: (@MainActor (String) -> Void)?

    static func fixture(store: StudyShellStore) -> Self {
        Self(
            play: {},
            selectMode: store.selectMode,
            cycleVisibility: store.cycleVisibility,
            toggleAutoplay: store.toggleAutoplay,
            toggleRepeatPause: store.togglePause,
            next: store.next,
            markTooEasy: store.markTooEasy,
            selectCourse: { _ in },
            restartCourse: nil
        )
    }
}

public struct MainStudyView: View {
    @Bindable private var store: StudyShellStore
    @Bindable private var courseDrawerStore: CourseDrawerStore
    @Bindable private var progressDrawerStore: ProgressDrawerStore
    @Bindable private var completionDialogStore: CompletionDialogStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var hasAppeared = false
    private let actions: StudyViewActions

    public init(store: StudyShellStore) {
        self.store = store
        self.courseDrawerStore = CourseDrawerStore()
        self.progressDrawerStore = ProgressDrawerStore()
        self.completionDialogStore = CompletionDialogStore()
        actions = .fixture(store: store)
    }

    public init(store: StudyShellStore, courseDrawerStore: CourseDrawerStore) {
        self.store = store
        self.courseDrawerStore = courseDrawerStore
        self.progressDrawerStore = ProgressDrawerStore()
        self.completionDialogStore = CompletionDialogStore()
        actions = .fixture(store: store)
    }

    public init(
        store: StudyShellStore,
        courseDrawerStore: CourseDrawerStore,
        progressDrawerStore: ProgressDrawerStore
    ) {
        self.store = store
        self.courseDrawerStore = courseDrawerStore
        self.progressDrawerStore = progressDrawerStore
        self.completionDialogStore = CompletionDialogStore()
        actions = .fixture(store: store)
    }

    public init(
        store: StudyShellStore,
        courseDrawerStore: CourseDrawerStore,
        progressDrawerStore: ProgressDrawerStore,
        completionDialogStore: CompletionDialogStore
    ) {
        self.store = store
        self.courseDrawerStore = courseDrawerStore
        self.progressDrawerStore = progressDrawerStore
        self.completionDialogStore = completionDialogStore
        actions = .fixture(store: store)
    }

    init(
        store: StudyShellStore,
        courseDrawerStore: CourseDrawerStore,
        progressDrawerStore: ProgressDrawerStore,
        completionDialogStore: CompletionDialogStore,
        actions: StudyViewActions
    ) {
        self.store = store
        self.courseDrawerStore = courseDrawerStore
        self.progressDrawerStore = progressDrawerStore
        self.completionDialogStore = completionDialogStore
        self.actions = actions
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            PosterBackground(palette: store.state.palette) {
                GeometryReader { geometry in
                    if dynamicTypeSize.isAccessibilitySize {
                        ScrollView {
                            pageContent
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: geometry.size.height, alignment: .top)
                        }
                        .scrollIndicators(.hidden)
                    } else {
                        pageContent
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
            }
            .accessibilityHidden(isModalPresented)
            .allowsHitTesting(!isModalPresented)
            .id(isModalPresented ? "study-background-modal" : "study-background-active")
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("主学习页")
                .accessibilityIdentifier("study.page")
                .accessibilityHidden(isModalPresented)
                .id(isModalPresented ? "study-page-modal" : "study-page-active")

            if completionDialogStore.state.isPresented {
                CompletionDialogView(
                    store: completionDialogStore,
                    palette: store.state.palette,
                    onChooseCourse: courseDrawerStore.present,
                    onRestartCourse: actions.restartCourse
                )
                .transition(.opacity)
                .zIndex(20)
            } else if courseDrawerStore.state.isPresented {
                CourseDrawerView(
                    store: courseDrawerStore,
                    palette: store.state.palette,
                    onSelectCourse: actions.selectCourse
                )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(10)
            } else if progressDrawerStore.state.isPresented {
                ProgressDrawerView(store: progressDrawerStore, palette: store.state.palette)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(
            .easeInOut(duration: WordLoopMotion.drawer(reduceMotion: motionReduced).duration),
            value: courseDrawerStore.state.isPresented
        )
        .animation(
            .easeInOut(duration: WordLoopMotion.drawer(reduceMotion: motionReduced).duration),
            value: progressDrawerStore.state.isPresented
        )
        .animation(
            .easeInOut(duration: WordLoopMotion.exit(reduceMotion: motionReduced).duration),
            value: completionDialogStore.state.isPresented
        )
        .onAppear {
            let motion = WordLoopMotion.contentEnter(reduceMotion: motionReduced)
            withAnimation(.easeOut(duration: motion.duration)) {
                hasAppeared = true
            }
        }
    }

    private var pageContent: some View {
        VStack(spacing: WordLoopSpacing.sm) {
            topBar
            Spacer(minLength: dynamicTypeSize.isAccessibilitySize ? WordLoopSpacing.safe : WordLoopSpacing.sm)
            learningStage
            if store.state.mode == .repeat { repeatCard }
            Spacer(minLength: WordLoopSpacing.sm)
            bottomBar
        }
        .offset(y: hasAppeared ? 0 : WordLoopMotion.contentEnter(reduceMotion: motionReduced).displacement)
        .opacity(hasAppeared ? 1 : 0)
        .animation(.easeInOut(duration: WordLoopMotion.palette(reduceMotion: motionReduced).duration), value: store.state.palette.id)
    }

    @ViewBuilder
    private var topBar: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: WordLoopSpacing.xs) {
                HStack {
                    courseButton
                    Spacer()
                    progressButton
                }
                modeSwitch
            }
        } else {
            HStack(alignment: .center, spacing: WordLoopSpacing.xs) {
                courseButton
                Spacer(minLength: 0)
                modeSwitch
                Spacer(minLength: 0)
                progressButton
            }
        }
    }

    private var courseButton: some View {
        Button("COURSE") {
            if progressDrawerStore.state.isPresented { progressDrawerStore.dismiss(reason: .header) }
            courseDrawerStore.present()
        }
            .font(WordLoopTypography.label(size: 10))
            .frame(minWidth: WordLoopSpacing.minimumHit, minHeight: WordLoopSpacing.minimumHit)
            .buttonStyle(.plain)
            .accessibilityLabel("选择课程")
            .accessibilityIdentifier("study.course")
    }

    private var progressButton: some View {
        Button("PROGRESS") {
            if courseDrawerStore.state.isPresented { courseDrawerStore.dismiss(reason: .header) }
            progressDrawerStore.present()
        }
            .font(WordLoopTypography.label(size: 10))
            .frame(minWidth: WordLoopSpacing.minimumHit, minHeight: WordLoopSpacing.minimumHit)
            .buttonStyle(.plain)
            .accessibilityLabel("查看学习进度")
            .accessibilityIdentifier("study.progress")
    }

    private var modeSwitch: some View {
        ModeSwitch(
            options: StudyShellMode.allCases.map(\.title),
            selection: Binding(
                get: { store.state.mode.title },
                set: { title in
                    if let mode = StudyShellMode(rawValue: title.lowercased()) {
                        actions.selectMode(mode)
                    }
                }
            ),
            accessibilityLabel: "学习模式",
            accessibilityIdentifierPrefix: "study.mode"
        )
    }

    private var learningStage: some View {
        VStack(spacing: WordLoopSpacing.md) {
            HStack {
                Text(store.state.courseLabel)
                    .font(WordLoopTypography.label(size: 10))
                    .accessibilityIdentifier("study.course-context")
                Spacer()
                Text(store.state.progressLabel)
                    .font(WordLoopTypography.label(size: 10))
                    .accessibilityLabel("第 \(store.state.currentIndex) 条，共 \(store.state.totalCount) 条")
                    .accessibilityIdentifier("study.progress-count")
            }

            learningCopy

            HStack(spacing: WordLoopSpacing.xs) {
                Button(action: actions.play) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: WordLoopSpacing.minimumHit, height: WordLoopSpacing.minimumHit)
                        .background(store.state.palette.ink.color, in: Circle())
                        .foregroundStyle(store.state.palette.background.color)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("播放当前学习内容")
                .accessibilityIdentifier("study.play")

                Button(action: actions.cycleVisibility) {
                    Image(systemName: visibilityIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: WordLoopSpacing.minimumHit, height: WordLoopSpacing.minimumHit)
                        .overlay(Circle().stroke(store.state.palette.ink.color, lineWidth: WordLoopBorder.hairline))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.state.visibility.nextAccessibilityAction(for: store.state.item.kind))
                .accessibilityValue(store.state.visibility.accessibilityValue)
                .accessibilityIdentifier("study.visibility")
            }
        }
    }

    @ViewBuilder
    private var learningCopy: some View {
        VStack(spacing: WordLoopSpacing.xs) {
            if store.state.visibility == .hidden {
                Text("••••••••")
                    .font(WordLoopTypography.posterTitle(size: 46))
                    .accessibilityLabel("学习内容已隐藏")
                    .accessibilityIdentifier("study.hidden-copy")
            } else {
                highlightedEnglish
                    .font(WordLoopTypography.posterTitle(size: store.state.item.kind == .word ? 72 : 48))
                    .multilineTextAlignment(.center)
                    .wordLoopPosterTitleLayout()
                    .accessibilityLabel(englishAccessibilityLabel)
                    .accessibilityIdentifier("study.english")
            }

            if store.state.visibility != .hidden {
                if let phonetic = store.state.item.phonetic {
                    Text(phonetic)
                        .font(WordLoopTypography.body(size: 16, weight: .semibold))
                        .foregroundStyle(store.state.palette.accessibleAccentText.color)
                        .accessibilityIdentifier("study.phonetic")
                }
                Text(store.state.item.translation)
                    .font(WordLoopTypography.body(size: 16, weight: .semibold))
                    .foregroundStyle(store.state.palette.accessibleAccentText.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("study.translation")
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: actions.next)
    }

    private var highlightedEnglish: Text {
        store.state.item.textSegments().reduce(Text("")) { result, segment in
            let visible = store.state.visibility == .focus && !segment.isHighlighted
                ? segment.text.map { $0.isWhitespace ? String($0) : "•" }.joined()
                : segment.text
            let text = Text(visible)
            return result + (segment.isHighlighted
                ? text.underline(true, color: store.state.palette.ink.color)
                : text)
        }
    }

    private var repeatCard: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: WordLoopSpacing.sm) { repeatCardElements }
            } else {
                HStack(spacing: WordLoopSpacing.md) { repeatCardElements }
            }
        }
        .padding(.horizontal, WordLoopSpacing.md)
        .padding(.vertical, WordLoopSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 92)
        .overlay {
            RoundedRectangle(cornerRadius: WordLoopRadius.card)
                .stroke(store.state.palette.ink.color, lineWidth: WordLoopBorder.hairline)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("study.repeat-card")
    }

    @ViewBuilder
    private var repeatCardElements: some View {
        repeatVisual
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .center : .leading, spacing: WordLoopSpacing.xxs) {
            MonoLabel(store.state.repeatPresentationState.title)
            Text(store.state.repeatPresentationState.instruction)
                .font(WordLoopTypography.body(size: 14, weight: .semibold))
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .center : .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(store.state.repeatPresentationState.accessibilityLabel)
        .accessibilityIdentifier("study.repeat-state.\(store.state.repeatPresentationState.rawValue)")

        if let transcript = store.state.repeatTranscript {
            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .center : .leading, spacing: WordLoopSpacing.xxs) {
                MonoLabel("You said", color: store.state.palette.accessibleAccentText.color)
                Text(transcript)
                    .font(WordLoopTypography.body(size: 13, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("You said，\(transcript)")
            .accessibilityIdentifier("study.repeat-transcript")
        }
        if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
    }

    @ViewBuilder
    private var repeatVisual: some View {
        switch store.state.repeatPresentationState.visualKind {
        case .success:
            let success = store.state.palette.accessibleStatusVisual(.init(hex: 0x148263))
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .bold))
                .frame(width: 64, height: 64)
                .foregroundStyle(success.color)
                .overlay(Circle().stroke(success.color, lineWidth: WordLoopBorder.emphasized))
                .accessibilityHidden(true)
                .accessibilityIdentifier("study.repeat-result")
        case .idleWaveform:
            repeatWaveform(.idle)
        case .activeWaveform:
            repeatWaveform(.active)
        case .emphasizedWaveform:
            repeatWaveform(.active, tint: store.state.palette.accessibleAccentText)
        case .failure:
            repeatWaveform(.failure)
        }
    }

    private func repeatWaveform(_ state: WaveformState, tint: WordLoopSRGB? = nil) -> some View {
        Waveform(
            state: state,
            palette: store.state.palette,
            accessibilityLabel: "跟读状态波形",
            tint: tint
        )
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: WordLoopSpacing.xs) {
                masteryControls.frame(maxWidth: .infinity, alignment: .leading)
                playbackControls.frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            HStack(alignment: .bottom, spacing: WordLoopSpacing.sm) {
                masteryControls
                Spacer(minLength: 0)
                playbackControls
            }
        }
    }

    private var masteryControls: some View {
        HStack(spacing: WordLoopSpacing.xs) {
            Button(action: {}) {
                Text("\(store.state.masteryCount) / 3")
                    .font(WordLoopTypography.label(size: 11))
                    .frame(minHeight: WordLoopSpacing.minimumHit)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("熟练度 \(store.state.masteryCount) / 3")
            .accessibilityIdentifier("study.mastery")

            Button(action: actions.markTooEasy) {
                Text("太简单 ✓")
                    .font(WordLoopTypography.label(size: 11))
                    .frame(minHeight: WordLoopSpacing.minimumHit)
            }
            .buttonStyle(.plain)
            .disabled(store.state.isTooEasyDisabled)
            .accessibilityIdentifier("study.too-easy")
        }
    }

    private var playbackControls: some View {
        HStack(spacing: WordLoopSpacing.xs) {
            Button(action: primaryAction) {
                Text(primaryTitle)
                    .font(WordLoopTypography.label(size: 11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(minWidth: 64, minHeight: WordLoopSpacing.minimumHit)
                    .padding(.horizontal, WordLoopSpacing.xs)
                    .overlay(Capsule().stroke(store.state.palette.ink.color, lineWidth: WordLoopBorder.hairline))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("study.primary-control")

            Button(action: actions.next) {
                Label("NEXT", systemImage: "arrow.right")
                    .font(WordLoopTypography.label(size: 11))
                    .labelStyle(.titleAndIcon)
                    .frame(minWidth: 58, minHeight: WordLoopSpacing.minimumHit)
            }
            .buttonStyle(.plain)
            .disabled(store.state.isNextDisabled)
            .accessibilityIdentifier("study.next")
        }
    }

    private var primaryTitle: String {
        switch store.state.mode {
        case .listen: store.state.isAutoplayEnabled ? "AUTOPLAY ON" : "AUTOPLAY"
        case .repeat: store.state.isRepeatPaused ? "RESUME" : "PAUSE"
        }
    }

    private func primaryAction() {
        switch store.state.mode {
        case .listen: actions.toggleAutoplay()
        case .repeat: actions.toggleRepeatPause()
        }
    }

    private var visibilityIcon: String {
        switch store.state.visibility {
        case .full: "eye"
        case .focus: "scope"
        case .hidden: "eye.slash"
        }
    }

    private var englishAccessibilityLabel: String {
        if store.state.visibility == .focus {
            let highlights = store.state.item.textSegments()
                .filter(\.isHighlighted)
                .map(\.text)
                .joined(separator: "，")
            return highlights.isEmpty ? store.state.item.english : "重点表达：\(highlights)"
        }
        return store.state.item.english
    }

    private var motionReduced: Bool {
        reduceMotion || ProcessInfo.processInfo.arguments.contains("-wordloop-fixture-reduce-motion")
    }

    private var isDrawerPresented: Bool {
        courseDrawerStore.state.isPresented || progressDrawerStore.state.isPresented
    }

    private var isModalPresented: Bool {
        completionDialogStore.state.isPresented || isDrawerPresented
    }
}
