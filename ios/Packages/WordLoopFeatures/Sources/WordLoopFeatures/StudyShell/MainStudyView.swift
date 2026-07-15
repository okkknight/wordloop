import SwiftUI
import WordLoopDesignSystem

public struct MainStudyView: View {
    @Bindable private var store: StudyShellStore
    @Bindable private var courseDrawerStore: CourseDrawerStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var hasAppeared = false

    public init(store: StudyShellStore) {
        self.store = store
        self.courseDrawerStore = CourseDrawerStore()
    }

    public init(store: StudyShellStore, courseDrawerStore: CourseDrawerStore) {
        self.store = store
        self.courseDrawerStore = courseDrawerStore
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
            .accessibilityHidden(courseDrawerStore.state.isPresented)
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("主学习页")
                .accessibilityIdentifier("study.page")
                .accessibilityHidden(courseDrawerStore.state.isPresented)

            if courseDrawerStore.state.isPresented {
                CourseDrawerView(store: courseDrawerStore, palette: store.state.palette)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(
            .easeInOut(duration: WordLoopMotion.drawer(reduceMotion: motionReduced).duration),
            value: courseDrawerStore.state.isPresented
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
        Button("COURSE", action: courseDrawerStore.present)
            .font(WordLoopTypography.label(size: 10))
            .frame(minWidth: WordLoopSpacing.minimumHit, minHeight: WordLoopSpacing.minimumHit)
            .buttonStyle(.plain)
            .accessibilityLabel("选择课程")
            .accessibilityIdentifier("study.course")
    }

    private var progressButton: some View {
        Button("PROGRESS") {}
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
                        store.selectMode(mode)
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
                Button {} label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: WordLoopSpacing.minimumHit, height: WordLoopSpacing.minimumHit)
                        .background(store.state.palette.ink.color, in: Circle())
                        .foregroundStyle(store.state.palette.background.color)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("播放当前学习内容")
                .accessibilityIdentifier("study.play")

                Button(action: store.cycleVisibility) {
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
        HStack(spacing: WordLoopSpacing.md) {
            Waveform(
                state: .active,
                palette: store.state.palette,
                accessibilityLabel: "标准发音波形"
            )
            VStack(alignment: .leading, spacing: WordLoopSpacing.xxs) {
                MonoLabel(store.state.repeatPresentationState.title)
                Text(store.state.repeatPresentationState.instruction)
                    .font(WordLoopTypography.body(size: 14, weight: .semibold))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, WordLoopSpacing.md)
        .padding(.vertical, WordLoopSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 92)
        .overlay {
            RoundedRectangle(cornerRadius: WordLoopRadius.card)
                .stroke(store.state.palette.ink.color, lineWidth: WordLoopBorder.hairline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("LISTENING，先听一遍标准发音")
        .accessibilityIdentifier("study.repeat-card")
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

            Button(action: store.markTooEasy) {
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

            Button(action: store.next) {
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
        case .listen: store.toggleAutoplay()
        case .repeat: store.togglePause()
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
}
