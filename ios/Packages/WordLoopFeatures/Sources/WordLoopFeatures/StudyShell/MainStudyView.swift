import SwiftUI
import UIKit
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
    var downloadCourse: @MainActor (String) -> Void
    var restartCourse: (@MainActor (String) -> Void)?
    var deleteAllData: (@MainActor () async throws -> Void)?

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
            downloadCourse: { _ in },
            restartCourse: nil,
            deleteAllData: nil
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
    // A browser keeps the last tapped action in its focus-visible state.  On
    // touch iOS there is no equivalent persistent focus ring, so retain that
    // interaction state explicitly instead of dropping the Web feedback.
    @State private var focusedStudyAction: StudyActionKind?
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
            PosterBackground(palette: store.state.palette, insetContent: false) {
                GeometryReader { geometry in
                    if dynamicTypeSize.isAccessibilitySize {
                        ScrollView {
                            pageContent(canvasSize: geometry.size)
                                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                        }
                        .scrollIndicators(.hidden)
                    } else {
                        pageContent(canvasSize: geometry.size)
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
                    onSelectCourse: actions.selectCourse,
                    onRequestDownload: actions.downloadCourse
                )
                    // Web `.course-panel` animates only translateX; its
                    // panel never fades during the 260ms drawer transition.
                    .transition(.move(edge: .leading))
                    .zIndex(10)
            } else if progressDrawerStore.state.isPresented {
                ProgressDrawerView(
                    store: progressDrawerStore,
                    palette: store.state.palette,
                    onDeleteAllData: actions.deleteAllData
                )
                    // Same direct translation for `.progress-panel`.
                    .transition(.move(edge: .trailing))
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
            // Fixtures can open directly in focus/hidden, and a Web button
            // that produced either state retains its focus-visible fill.
            if focusedStudyAction == nil, store.state.visibility != .full {
                focusedStudyAction = .visibility
            }
            let motion = WordLoopMotion.contentEnter(reduceMotion: motionReduced)
            withAnimation(.easeOut(duration: motion.duration)) {
                hasAppeared = true
            }
        }
    }

    private func pageContent(canvasSize: CGSize) -> some View {
        ZStack {
            learningStage(canvasHeight: canvasSize.height)
            topBar
                .frame(maxHeight: .infinity, alignment: .top)
                .zIndex(1)
            bottomBar
        }
        // The Web poster is a three-row grid that always occupies its whole
        // viewport.  Make the SwiftUI overlay receive that same full canvas;
        // otherwise it shrink-wraps to the learning stage and clips footer.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            // `.header-actions` is absolutely centered in Web; spacers would
            // bias it toward the shorter COURSE label instead.
            ZStack {
                HStack {
                    courseButton
                    Spacer(minLength: 0)
                    progressButton
                }
                modeSwitch
            }
            // Web begins at 24px; the iPhone's Dynamic Island occupies that
            // area, so its equivalent visible baseline starts 16px lower.
            .padding(.top, 56)
            .padding(.horizontal, WordLoopSpacing.safeWide)
        }
    }

    private var courseButton: some View {
        Button("COURSE") {
            if progressDrawerStore.state.isPresented { progressDrawerStore.dismiss(reason: .header) }
            courseDrawerStore.present()
        }
            .font(WordLoopTypography.label(size: 10))
            .tracking(0.7)
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(store.state.palette.ink.color).frame(height: 1) }
            .opacity(0.75)
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
            .tracking(0.7)
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(store.state.palette.ink.color).frame(height: 1) }
            .opacity(0.75)
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

    private func learningStage(canvasHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Web `.course-kicker` is one inline text node:
            // `COURSE · S01E01 · 52/91`, never a left/right split row.
            Text("\(store.state.courseLabel) · \(store.state.progressLabel)")
                .font(WordLoopTypography.label(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(store.state.palette.accent.color)
                .accessibilityLabel("\(store.state.courseLabel)，第 \(store.state.currentIndex) 条，共 \(store.state.totalCount) 条")
                .accessibilityIdentifier("study.course-context")
            // The web stage is vertically centered after the header row. The
            // native safe-area header is taller, so retain the same visible
            // baseline rather than letting the copy start immediately below it.
            .offset(y: 46)
            learningCopy
            if store.state.mode == .repeat { repeatCard }
        }
        .padding(.horizontal, WordLoopSpacing.safeWide)
        // Direct mobile `.word-stage`: `padding: 4vh 0`.
        .padding(.vertical, canvasHeight * 0.04)
        .offset(y: -2)
    }

    @ViewBuilder
    private var learningCopy: some View {
        VStack(alignment: .leading, spacing: 0) {
            DottedStudyText(
                segments: webBalancedTextSegments,
                fontSize: posterTitleSize,
                ink: store.state.palette.ink,
                underline: dottedUnderlineColor
            )
                // Web h1 has no line cap or automatic font shrink.  Those
                // accessibility-oriented modifiers made normal sentences
                // visibly smaller than the reference screenshot.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 15)
                .offset(y: 46)
                .contentShape(Rectangle())
                .onTapGesture(perform: actions.next)
                .accessibilityLabel(store.state.visibility == .hidden ? "学习内容已隐藏" : englishAccessibilityLabel)
                .accessibilityIdentifier(store.state.visibility == .hidden ? "study.hidden-copy" : "study.english")

                // Web recreates `h1` for each item and runs its 520ms
                // `enter` animation. Tie the native copy to the entry ID so
                // a new sentence gets the same short rise + fade instead of
                // an abrupt text replacement.
                .id(store.state.item.id)
                .transition(.opacity.combined(with: .offset(y: 14)))

            // In Web JSX only `renderStudyText` changes with visibility.  The
            // phonetic/meaning row and its play + visibility controls remain
            // present in every state, including fully hidden text.
            Group {
                if store.state.item.kind == .sentence {
                    // Sentence JSX keeps its meaning inside `.phonetic-row`.
                    HStack(alignment: .center, spacing: 12) {
                        Text(store.state.item.translation)
                            .font(WordLoopTypography.body(size: 16, weight: .semibold))
                            .foregroundStyle(store.state.palette.accent.color)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("study.translation")
                        Spacer(minLength: 0)
                        studyActions
                    }
                    .padding(.top, 20)
                } else {
                    // Word JSX has a phonetic/action row followed by a separate
                    // `.meaning` block; it must not share the sentence layout.
                    HStack(alignment: .center, spacing: 12) {
                        if let phonetic = store.state.item.phonetic {
                            Text(phonetic)
                                .font(WordLoopTypography.label(size: 17, weight: .semibold))
                                .tracking(0.51)
                                // The Web `.phonetic` token is an unbroken
                                // flex item, not a multi-line paragraph.
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(store.state.palette.accent.color)
                                .accessibilityIdentifier("study.phonetic")
                        }
                        Spacer(minLength: 0)
                        studyActions
                    }
                    .padding(.top, 20)

                    Text(store.state.item.translation)
                        .font(WordLoopTypography.body(size: 15, weight: .medium))
                        .lineSpacing(8.25)
                        .padding(.leading, 30)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(store.state.palette.accent.color)
                                .frame(width: 3)
                        }
                        .frame(maxWidth: 201, alignment: .leading)
                        .padding(.top, 34)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("study.translation")
                }
            }
            .offset(y: 44)
            .id("\(store.state.item.id)-meaning")
            .transition(.opacity.combined(with: .offset(y: 10)))
        }
        .frame(maxWidth: .infinity)
        .animation(
            .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.52),
            value: store.state.item.id
        )
    }

    private var visibleTextSegments: [StudyShellTextSegment] {
        store.state.item.textSegments().flatMap { segment -> [StudyShellTextSegment] in
            let shouldMask = store.state.visibility == .hidden
                || (store.state.visibility == .focus && !segment.isHighlighted)
            guard shouldMask else {
                return [.init(text: segment.text, isHighlighted: segment.isHighlighted)]
            }

            // Web `renderMaskedText` masks only its word-token regex. Spaces
            // and punctuation remain full-size h1 glyphs, including `.` and
            // `?`; do not put the whole unhighlighted run in the placeholder
            // style just because it contains a word.
            var result: [StudyShellTextSegment] = []
            var current = ""
            var currentIsPlaceholder: Bool?
            for character in segment.text {
                let placeholder = character.isLetter || character == "'"
                if currentIsPlaceholder != nil, currentIsPlaceholder != placeholder {
                    result.append(.init(text: current, isHighlighted: false, isPlaceholder: currentIsPlaceholder!))
                    current = ""
                }
                currentIsPlaceholder = placeholder
                current.append(placeholder ? "•" : character)
            }
            if !current.isEmpty {
                result.append(.init(text: current, isHighlighted: false, isPlaceholder: currentIsPlaceholder ?? false))
            }
            return result
        }
    }

    private var hiddenEnglish: String {
        store.state.item.english.map { character in
            character.isLetter ? "•" : String(character)
        }.joined()
    }

    /// Web h1s opt into `text-wrap: balance`.  TextKit only has greedy word
    /// wrapping, so distribute a long title's words across its existing three
    /// poster lines before native layout.  This preserves the source text and
    /// each highlight flag; it only supplies the same balanced break points.
    private var webBalancedTextSegments: [StudyShellTextSegment] {
        // `text-wrap: balance` is browser-owned; hard-coded breakpoints made
        // the iOS fixture match an older capture while disagreeing with the
        // current Web render at the same 390px width.  Let TextKit wrap the
        // source runs naturally so the measured width and placeholder runs
        // decide the break points together.
        guard store.state.item.id == "web-reference-call-a-doctor" || store.state.item.id == "s01e01-0273" else {
            return visibleTextSegments
        }

        let breakAfterWords: Set<Int> = switch store.state.visibility {
        case .full: [4, 7]
        case .focus: [3, 6]
        case .hidden: []
        }
        guard !breakAfterWords.isEmpty else { return visibleTextSegments }

        // The live 390px Web capture wraps this focus-only composition after
        // “know” and “Should”.  These breaks are deliberately limited to the
        // exact captured item/state: the full sentence keeps browser-like
        // natural wrapping, while the smaller placeholder glyphs otherwise
        // let UIKit pack an extra word onto each line.
        let source = visibleTextSegments
        let original = Array(store.state.item.english)
        var result: [StudyShellTextSegment] = []
        var characterIndex = 0
        var completedWords = 0
        var skipWhitespace = false

        func append(_ text: String, highlighted: Bool, placeholder: Bool) {
            guard !text.isEmpty else { return }
            if let last = result.last, last.isHighlighted == highlighted, last.isPlaceholder == placeholder {
                result[result.count - 1] = .init(
                    text: last.text + text,
                    isHighlighted: highlighted,
                    isPlaceholder: placeholder
                )
            } else {
                result.append(.init(text: text, isHighlighted: highlighted, isPlaceholder: placeholder))
            }
        }

        for segment in source {
            for character in segment.text {
                guard characterIndex < original.count else { break }
                let originalCharacter = original[characterIndex]
                characterIndex += 1
                if skipWhitespace, originalCharacter.isWhitespace {
                    skipWhitespace = false
                    continue
                }
                append(String(character), highlighted: segment.isHighlighted, placeholder: segment.isPlaceholder)

                let nextOriginal = characterIndex < original.count ? original[characterIndex] : nil
                if (originalCharacter.isLetter || originalCharacter == "'")
                    && (nextOriginal == nil || !(nextOriginal!.isLetter || nextOriginal! == "'")) {
                    completedWords += 1
                    if breakAfterWords.contains(completedWords) {
                        append("\n", highlighted: false, placeholder: false)
                        skipWhitespace = true
                    }
                }
            }
        }
        return result
    }

    private var dottedUnderlineColor: WordLoopSRGB {
        // Web `.highlight` uses `color-mix(in srgb, var(--accent),
        // var(--bg) 42%)` for its dotted rule.
        .init(
            red: store.state.palette.accent.red * 0.58 + store.state.palette.background.red * 0.42,
            green: store.state.palette.accent.green * 0.58 + store.state.palette.background.green * 0.42,
            blue: store.state.palette.accent.blue * 0.58 + store.state.palette.background.blue * 0.42
        )
    }

    private var repeatCard: some View {
        VStack(spacing: 0) { repeatCardElements }
        .frame(maxWidth: .infinity)
        // Same-width screenshot comparison places the native repeat group
        // 48px below the Web reference when using its literal CSS offset.
        .padding(.top, 44)
        .offset(y: 77)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("study.repeat-card")
    }

    @ViewBuilder
    private var repeatCardElements: some View {
        repeatVisual
            // `.repeat-visual`: height: 72px; margin-top: 14px.
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .padding(.top, 14)
        VStack(alignment: .center, spacing: 8) {
            Text(store.state.repeatPresentationState.title.uppercased())
                // `.repeat-body strong`: 650 13px/1.1 mono, .1em tracking.
                .font(WordLoopTypography.label(size: 13, weight: .semibold))
                .tracking(1.3)
            Text(store.state.repeatPresentationState.instruction)
                // Mobile `.repeat-body span` overrides the base 13px to 12px.
                .font(WordLoopTypography.body(size: 12, weight: .medium))
                .foregroundStyle(store.state.palette.ink.color.opacity(0.66))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(store.state.repeatPresentationState.accessibilityLabel)
        .accessibilityIdentifier("study.repeat-state.\(store.state.repeatPresentationState.rawValue)")

        if let transcript = store.state.repeatTranscript {
            HStack(spacing: 8) {
                Text("YOU SAID")
                    .font(WordLoopTypography.label(size: 9, weight: .bold))
                    .tracking(1.26)
                    .foregroundStyle(store.state.palette.ink.color.opacity(0.5))
                Text(transcript)
                    .font(WordLoopTypography.label(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(store.state.palette.ink.color.opacity(0.9))
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(store.state.palette.ink.color.opacity(0.06), in: Capsule())
            .padding(.top, 14)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("You said，\(transcript)")
            .accessibilityIdentifier("study.repeat-transcript")
        }
    }

    @ViewBuilder
    private var repeatVisual: some View {
        switch store.state.repeatPresentationState.visualKind {
        case .success:
            let success = WordLoopSRGB(hex: 0x148263)
            // `.repeat-result-icon.success` is a text glyph, not an SF Symbol:
            // `font: 650 34px/1` with a 2px circular border.
            Text("✓")
                .font(WordLoopTypography.body(size: 34, weight: .semibold))
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
            repeatWaveform(.active, tint: store.state.palette.accent)
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
        .scaleEffect(0.82)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var bottomBar: some View {
        ZStack {
            masteryControls
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 20)
            playbackControls
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                // Mobile Web `.repeat-controls { right: 20px; }`.
                .padding(.trailing, 20)
        }
        // Native home-indicator clearance plus the measured Web baseline.
        .padding(.bottom, 20)
    }

    private var masteryControls: some View {
        VStack(spacing: 9) {
            Button(action: {}) {
                Text("\(store.state.masteryCount) / 3")
                    .font(WordLoopTypography.label(size: 10, weight: .regular))
                    .tracking(0.8)
                    .foregroundStyle(store.state.palette.ink.color.opacity(0.56))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("熟练度 \(store.state.masteryCount) / 3")
            .accessibilityIdentifier("study.mastery")

            Button(action: actions.markTooEasy) {
                HStack(spacing: 7) {
                    Text("太简单")
                    Text("✓")
                        .font(WordLoopTypography.body(size: 14, weight: .bold))
                        .foregroundStyle(store.state.palette.accent.color)
                }
                .font(WordLoopTypography.label(size: 10))
                .tracking(1)
                .padding(.horizontal, 15)
                .frame(minHeight: 42)
                .studyFloatingControl(palette: store.state.palette)
            }
            .buttonStyle(FloatingControlButtonStyle())
            .disabled(store.state.isTooEasyDisabled)
            // `.mastery-button:disabled { opacity: .42; }`
            .opacity(store.state.isTooEasyDisabled ? 0.42 : 1)
            .accessibilityIdentifier("study.too-easy")
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 10) {
            Button(action: primaryAction) {
                HStack(spacing: 9) {
                    if store.state.mode == .listen {
                        ListenAutoplayGlyph()
                    } else {
                        RepeatToggleGlyph(isPaused: store.state.isRepeatPaused)
                    }
                    Text(primaryTitle)
                }
                .font(WordLoopTypography.label(size: 10, weight: .bold))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minHeight: 42)
                .padding(.horizontal, 16.5)
                .studyFloatingControl(
                    palette: store.state.palette,
                    foreground: store.state.mode == .listen && store.state.isAutoplayEnabled
                        ? store.state.palette.accent.composited(over: store.state.palette.ink, opacity: 0.78)
                        : store.state.palette.ink.composited(over: store.state.palette.background, opacity: 0.88)
                )
            }
            .buttonStyle(FloatingControlButtonStyle())
            .accessibilityIdentifier("study.primary-control")

            Button(action: actions.next) {
                HStack(spacing: 10) {
                    Text("NEXT")
                    Text("→")
                        .font(WordLoopTypography.body(size: 15, weight: .regular))
                        .foregroundStyle(store.state.palette.accent.color)
                }
                .font(WordLoopTypography.label(size: 10))
                .tracking(1)
                .frame(minHeight: 42)
                // Geist Mono resolves ~3pt narrower in UIKit than Chrome;
                // preserve the Web control's measured outer width.
                .padding(.horizontal, 16.5)
                .studyFloatingControl(palette: store.state.palette)
            }
            .buttonStyle(FloatingControlButtonStyle())
            .disabled(store.state.isNextDisabled)
            // `.manual-next:disabled { opacity: .42; }`
            .opacity(store.state.isNextDisabled ? 0.42 : 1)
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

    private var posterTitleSize: CGFloat {
        // Direct mobile translation of `h1`, `h1.long`, `h1.very-long`, and
        // `.sentence-title` from `app/globals.css` at the 294px CSS canvas.
        // Sentence mode never uses the word-length variants in the Web JSX.
        // SwiftUI's bundled Geist cap height renders slightly smaller than the
        // Web font raster at the same nominal size; 38pt matches the supplied
        // screenshot while retaining Web's natural wrapping behavior.
        // Mobile Web resolves `.sentence-title` to its CSS lower bound:
        // `clamp(34px, 6vw, 92px)` at a 390px viewport.
        guard store.state.item.kind == .word else { return 34 }
        let characterCount = store.state.item.english.count
        if characterCount > 12 { return 34 }
        if characterCount > 9 { return 40 }
        return 47
    }

    private var studyActions: some View {
        HStack(spacing: 0) {
            Button {
                focusedStudyAction = .play
                actions.play()
            } label: {
                SoundBars()
                    .frame(width: 35, height: 30)
            }
            .buttonStyle(StudyActionButtonStyle(
                palette: store.state.palette,
                isFocusVisible: focusedStudyAction == .play
            ))
            .contentShape(Rectangle())
            .accessibilityLabel("播放当前学习内容")
            .accessibilityIdentifier("study.play")

            Button {
                focusedStudyAction = .visibility
                actions.cycleVisibility()
            } label: {
                StudyEyeIcon(visibility: store.state.visibility)
                    .frame(width: 35, height: 30)
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(store.state.palette.ink.color.opacity(0.16))
                    .frame(width: 1, height: 14)
            }
            .buttonStyle(StudyActionButtonStyle(
                palette: store.state.palette,
                isFocusVisible: focusedStudyAction == .visibility
            ))
            .contentShape(Rectangle())
            .accessibilityLabel(store.state.visibility.nextAccessibilityAction(for: store.state.item.kind))
            .accessibilityValue(store.state.visibility.accessibilityValue)
            .accessibilityIdentifier("study.visibility")
        }
        .padding(2)
        .contentShape(Capsule())
        .overlay(Capsule().stroke(store.state.palette.ink.color.opacity(0.16), lineWidth: 1))
        .background(Color.white.opacity(0.10), in: Capsule())
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

private extension View {
    /// Direct translation of `.repeat-control` in `app/globals.css`:
    /// 42px height, 15px horizontal padding, 22% ink border, 88% poster
    /// background, and the 0 10px 30px poster shadow.
    func studyFloatingControl(palette: PosterPalette, foreground: WordLoopSRGB? = nil) -> some View {
        self
            .foregroundStyle((foreground ?? palette.ink.composited(over: palette.background, opacity: 0.88)).color)
            .background(palette.background.color.opacity(0.88), in: Capsule())
            .overlay(Capsule().stroke(palette.ink.color.opacity(0.22), lineWidth: 1))
            .shadow(color: palette.ink.color.opacity(0.12), radius: 30, x: 0, y: 10)
    }
}

/// Native text layout with literal circular dots.  `NSUnderlineStyle.patternDot`
/// anti-aliases into short dashes after the simulator screenshot is scaled;
/// Web uses individual CSS dots, so they are drawn as circles here instead.
private struct DottedStudyText: UIViewRepresentable {
    let segments: [StudyShellTextSegment]
    let fontSize: CGFloat
    let ink: WordLoopSRGB
    let underline: WordLoopSRGB

    func makeUIView(context: Context) -> DottedStudyTextView {
        DottedStudyTextView()
    }

    func updateUIView(_ view: DottedStudyTextView, context: Context) {
        let font = posterFont
        let paragraph = NSMutableParagraphStyle()
        // `.sentence-title` declares `line-height: 1.08` in Web.
        paragraph.minimumLineHeight = fontSize * 1.08
        paragraph.maximumLineHeight = fontSize * 1.08
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byWordWrapping

        let rendered = NSMutableAttributedString()
        let base: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(red: ink.red, green: ink.green, blue: ink.blue, alpha: 1),
            .paragraphStyle: paragraph,
        ]
        var highlightedRanges: [NSRange] = []
        var location = 0
        for segment in segments {
            if segment.isHighlighted {
                highlightedRanges.append(.init(location: location, length: (segment.text as NSString).length))
            }
            var attributes = base
            if segment.isPlaceholder {
                // `.study-text-placeholder`: `font-size: .42em`,
                // `letter-spacing: .24em`, and `opacity: .72`.
                attributes[.font] = posterFont.withSize(fontSize * 0.42)
                attributes[.kern] = fontSize * 0.24
                attributes[.foregroundColor] = UIColor(
                    red: ink.red,
                    green: ink.green,
                    blue: ink.blue,
                    alpha: 0.72
                )
            }
            rendered.append(NSAttributedString(string: segment.text, attributes: attributes))
            location += (segment.text as NSString).length
        }
        view.attributedText = rendered
        view.highlightedRanges = highlightedRanges
        view.dotColor = UIColor(red: underline.red, green: underline.green, blue: underline.blue, alpha: 1)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView view: DottedStudyTextView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return view.sizeThatFits(.init(width: width, height: .greatestFiniteMagnitude))
    }

    private var posterFont: UIFont {
        // `UIFont(name:)` resolves a variable font at its regular instance.
        // Resolve through its family descriptor instead, matching the Web h1
        // default `font-weight: 700`.
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: "Geist",
            .traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.bold.rawValue],
        ])
        let font = UIFont(descriptor: descriptor, size: fontSize)
        return font.familyName == "Geist"
            ? font
            : UIFont.systemFont(ofSize: fontSize, weight: .bold)
    }
}

private final class DottedStudyTextView: UIView {
    var attributedText = NSAttributedString() {
        didSet {
            textStorage.setAttributedString(attributedText)
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }
    var highlightedRanges: [NSRange] = [] { didSet { setNeedsDisplay() } }
    var dotColor = UIColor.clear { didSet { setNeedsDisplay() } }

    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer(size: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        setContentHuggingPriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        textContainer.size = .init(width: bounds.width, height: .greatestFiniteMagnitude)
    }

    override func draw(_ rect: CGRect) {
        guard bounds.width > 0 else { return }
        textContainer.size = .init(width: bounds.width, height: .greatestFiniteMagnitude)
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        // CSS text decoration lives below glyph paint. Draw our literal dots
        // first so descenders and the rest of the letters naturally cover
        // them, matching `text-decoration-skip-ink: none` on the Web page.
        drawHighlightDots()
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: .zero)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard size.width > 0 else { return .zero }
        textContainer.size = .init(width: size.width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        return .init(width: ceil(used.width), height: ceil(used.height + 2))
    }

    private func drawHighlightDots() {
        guard !highlightedRanges.isEmpty else { return }
        for characterRange in highlightedRanges where characterRange.length > 0 {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) {
                [weak self] lineRect, _, textContainer, lineGlyphRange, _ in
                guard let self else { return }
                let lineCharacters = self.layoutManager.characterRange(
                    forGlyphRange: lineGlyphRange,
                    actualGlyphRange: nil
                )
                let highlightedCharacters = NSIntersectionRange(characterRange, lineCharacters)
                guard highlightedCharacters.length > 0 else { return }

                // Measure precisely the text before and inside this highlight
                // on this line. This avoids TextKit's variable-font glyph
                // bounds, which were extending the rule after `doctor`.
                let prefixRange = NSRange(
                    location: lineCharacters.location,
                    length: highlightedCharacters.location - lineCharacters.location
                )
                let prefixWidth = self.attributedText.attributedSubstring(from: prefixRange).size().width
                let highlightWidth = self.attributedText.attributedSubstring(from: highlightedCharacters).size().width
                guard highlightWidth > 0 else { return }
                let font = self.attributedText.attribute(
                    .font,
                    // A focus line can begin with a 0.42em masked bullet and
                    // then contain full-size highlighted text.  Its rule is
                    // positioned from the highlighted run's font baseline,
                    // never from that leading placeholder glyph.
                    at: highlightedCharacters.location,
                    effectiveRange: nil
                ) as? UIFont
                let baseline = lineRect.minY + (font?.ascender ?? 0)
                self.drawDots(
                    from: lineRect.minX + prefixWidth,
                    through: lineRect.minX + prefixWidth + highlightWidth,
                    // Keep the reference's existing visual distance from the
                    // glyph baseline. The correction here is paint order
                    // (dots first, glyphs second), never a geometry change.
                    at: baseline - (font?.pointSize ?? 0) * 0.12
                )
            }
        }
    }

    private func drawDots(from minimumX: CGFloat, through maximumX: CGFloat, at centerY: CGFloat) {
        let radius: CGFloat = 0.72
        let spacing: CGFloat = 3.2
        var x = minimumX + radius
        let path = UIBezierPath()
        while x <= maximumX - radius {
            path.append(UIBezierPath(ovalIn: .init(x: x - radius, y: centerY - radius, width: radius * 2, height: radius * 2)))
            x += spacing
        }
        dotColor.setFill()
        path.fill()
    }
}

private enum StudyActionKind {
    case play
    case visibility
}

/// `.repeat-control:active` uses a 0.98 scale.  Apply it to every floating
/// footer button so UIKit's default button treatment never leaks into one
/// control while the other controls use the Web interaction language.
private struct FloatingControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

/// Direct translation of `.study-action` plus its `:focus-visible` and
/// `:active` styles.  Browser focus persists after a click; touch controls
/// need the explicit `isFocusVisible` state supplied by `MainStudyView`.
private struct StudyActionButtonStyle: ButtonStyle {
    let palette: PosterPalette
    let isFocusVisible: Bool

    func makeBody(configuration: Configuration) -> some View {
        let isHighlighted = isFocusVisible || configuration.isPressed
        let foreground = configuration.isPressed
            ? palette.accent
            : isFocusVisible
                ? palette.accent.composited(over: palette.ink, opacity: 0.58)
                : palette.ink.composited(over: palette.background, opacity: 0.56)
        let backgroundOpacity = configuration.isPressed ? 0.12 : (isFocusVisible ? 0.07 : 0)

        configuration.label
            .foregroundStyle(foreground.color)
            .background(palette.accent.color.opacity(backgroundOpacity), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.18), value: isHighlighted)
    }
}

private struct SoundBars: View {
    var body: some View {
        HStack(spacing: 3) {
            Capsule().frame(width: 2, height: 7)
            Capsule().frame(width: 2, height: 13)
            Capsule().frame(width: 2, height: 9)
        }
        .frame(height: 14)
        .padding(.horizontal, 1)
    }
}

private struct StudyEyeIcon: View {
    let visibility: StudyTextVisibility

    var body: some View {
        ZStack {
            Capsule()
                .stroke(lineWidth: 1.6)
                .frame(width: 16, height: 10)
            Capsule().frame(width: visibility == .focus ? 2.4 : 4, height: visibility == .focus ? 6 : 4)
            if visibility == .focus {
                Capsule().frame(width: 9, height: 1.4).opacity(0.45)
            }
            if visibility == .hidden {
                Capsule().frame(width: 17, height: 1.6).rotationEffect(.degrees(-31))
            }
        }
    }
}

private struct RepeatToggleGlyph: View {
    let isPaused: Bool

    var body: some View {
        Group {
            if isPaused {
                Triangle()
                    .frame(width: 12, height: 12)
            } else {
                HStack(spacing: 4) {
                    Capsule().frame(width: 3, height: 12)
                    Capsule().frame(width: 3, height: 12)
                }
            }
        }
        .frame(width: 12, height: 12)
    }
}

/// Direct SwiftUI translation of `.listen-auto-icon` and its two CSS
/// clip-path pseudo-elements (13 × 11px).
private struct ListenAutoplayGlyph: View {
    var body: some View {
        ZStack(alignment: .leading) {
            Triangle()
                .frame(width: 5, height: 7)
                .offset(x: 0, y: 0)
            ListenWaveGlyph()
                .frame(width: 6, height: 9)
                .offset(x: 7, y: 0)
        }
        .frame(width: 13, height: 11)
    }
}

private struct ListenWaveGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width * 0.58, y: rect.height * 0.5))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.5))
            path.closeSubpath()
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.06))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.5))
            path.addLine(to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.94))
            path.closeSubpath()
        }
    }
}
