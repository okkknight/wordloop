import SwiftUI
import WordLoopDesignSystem

public struct StartupView: View {
    @Bindable private var store: StartupStore
    private let onSubmission: (StartupSubmission) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var usernameIsFocused: Bool
    @State private var hasAppeared = false

    private let palette = StartupVisualRoles.palette

    public init(
        store: StartupStore,
        onSubmission: @escaping (StartupSubmission) -> Void = { _ in }
    ) {
        self.store = store
        self.onSubmission = onSubmission
    }

    public var body: some View {
        PosterBackground(palette: palette) {
            Color.clear
        }
        .overlay {
            palette.background.color
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .overlay { contentOverlay }
        .accessibilityIdentifier("startup.page")
        .onAppear {
            let motion = WordLoopMotion.contentEnter(reduceMotion: motionReduced)
            withAnimation(.easeOut(duration: motion.duration)) {
                hasAppeared = true
            }
        }
    }

    private var contentOverlay: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: WordLoopSpacing.safeWide)
                    form
                    Spacer(minLength: WordLoopSpacing.safeWide)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
    }

    private var form: some View {
        VStack(spacing: WordLoopSpacing.lg) {
            usernameField
            startButton
            if let helperText = store.state.helperText {
                Text(helperText)
                    .font(WordLoopTypography.label(size: 11))
                    .foregroundStyle(palette.ink.color.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("startup.helper")
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .padding(.horizontal, WordLoopSpacing.safeWide)
        .padding(.vertical, WordLoopSpacing.safeWide)
        .offset(y: hasAppeared ? 0 : WordLoopMotion.contentEnter(reduceMotion: motionReduced).displacement)
        .opacity(hasAppeared ? 1 : 0)
        .accessibilityElement(children: .contain)
    }

    private var usernameField: some View {
        VStack(spacing: WordLoopSpacing.xs) {
            TextField(
                "",
                text: Binding(
                    get: { store.username },
                    set: { store.updateUsername($0) }
                ),
                prompt: Text("USERNAME")
                    .font(WordLoopTypography.label(size: 10))
                    .tracking(1.6)
                    .foregroundStyle(StartupVisualRoles.placeholder.foreground.color)
            )
            .font(WordLoopTypography.label(size: 14))
            .tracking(1.68)
            .foregroundStyle(palette.ink.color)
            .tint(palette.accent.color)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 238)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(StartupVisualRoles.inputBoundary.foreground.color)
                    .frame(height: WordLoopBorder.hairline)
                    .accessibilityHidden(true)
            }
            .focused($usernameIsFocused)
            .autocorrectionDisabled(true)
            .startupUsernameInputTraits()
            .submitLabel(.go)
            .onSubmit(submit)
            .accessibilityLabel("用户名，可选")
            .accessibilityHint(store.validationMessage ?? "仅可使用英文字母，留空将匿名进入")
            .accessibilityIdentifier("startup.username")

            if let validationMessage = store.validationMessage {
                Text(validationMessage)
                    .font(WordLoopTypography.label(size: 10))
                    .foregroundStyle(palette.accessibleAccentText.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("startup.error")
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var startButton: some View {
        Button(action: submit) {
            HStack(spacing: 14) {
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.accessibleAccentText.color)
                    .accessibilityHidden(true)
                Text(store.state.buttonTitle)
                    .font(WordLoopTypography.label(size: 13))
                    .tracking(1.04)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .frame(minWidth: 100, minHeight: WordLoopSpacing.minimumHit)
            .padding(.horizontal, WordLoopSpacing.sm)
            .foregroundStyle(palette.ink.color)
            .background(Color.clear, in: Capsule())
            .overlay {
                Capsule().stroke(palette.ink.color.opacity(0.84), lineWidth: WordLoopBorder.emphasized)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(store.state.isBusy)
        .opacity(store.state.isBusy ? 0.72 : 1)
        .accessibilityLabel(store.state.buttonTitle)
        .accessibilityValue(buttonAccessibilityValue)
        .accessibilityIdentifier("startup.submit")
    }

    private var buttonAccessibilityValue: String {
        if store.state.isBusy { return "处理中" }
        guard let submission = store.lastSubmission else { return "可提交" }
        switch submission {
        case .anonymous:
            return "已提交匿名用户"
        case .named(let username):
            return "已提交用户 \(username)"
        }
    }

    private func submit() {
        guard let submission = store.submit() else { return }
        usernameIsFocused = false
        onSubmission(submission)
    }

    private var motionReduced: Bool {
        reduceMotion || ProcessInfo.processInfo.arguments.contains("-wordloop-fixture-reduce-motion")
    }
}

private extension View {
    @ViewBuilder
    func startupUsernameInputTraits() -> some View {
#if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .keyboardType(.asciiCapable)
            .textContentType(.username)
#else
        self
#endif
    }
}
