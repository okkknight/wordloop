import SwiftUI
import WordLoopDesignSystem

public struct StartupView: View {
    @Bindable private var store: StartupStore
    private let onSubmission: (StartupSubmission) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            // Direct `.start-overlay`: a 92% poster-color veil over a
            // 12px blur. Keep the underlying poster motif visible rather
            // than replacing it with an unrelated blank system surface.
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(palette.background.color.opacity(0.92))
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

    private var startButton: some View {
        Button(action: submit) {
            HStack(spacing: 14) {
                Text("▶")
                    .font(WordLoopTypography.body(size: 12, weight: .bold))
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
        let copy = StartupAccessibilityCopy.current
        if store.state.isBusy { return copy.processing }
        guard let submission = store.lastSubmission else { return copy.available }
        switch submission {
        case .anonymous:
            return copy.anonymous
        case .named(let username):
            return "\(copy.named) \(username)"
        }
    }

    private func submit() {
        guard let submission = store.submit() else { return }
        onSubmission(submission)
    }

    private var motionReduced: Bool {
        reduceMotion || ProcessInfo.processInfo.arguments.contains("-wordloop-fixture-reduce-motion")
    }
}
