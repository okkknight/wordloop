import Foundation
import SwiftUI

private struct PosterPaletteEnvironmentKey: EnvironmentKey {
    static let defaultValue = PosterPalette.defaultPalette
}

private extension View {
    @ViewBuilder
    func optionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            self.accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}

private extension EnvironmentValues {
    var posterPalette: PosterPalette {
        get { self[PosterPaletteEnvironmentKey.self] }
        set { self[PosterPaletteEnvironmentKey.self] = newValue }
    }
}

public struct PosterBackground<Content: View>: View {
    private let palette: PosterPalette
    private let content: Content

    public init(palette: PosterPalette, @ViewBuilder content: () -> Content) {
        self.palette = palette
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            palette.background.color.ignoresSafeArea()
            Circle()
                .stroke(palette.accent.color.opacity(WordLoopLayerOpacity.posterAccent), lineWidth: 58)
                .frame(width: 310, height: 310)
                .offset(x: 152, y: -154)
                .accessibilityHidden(true)
            content
                .foregroundStyle(palette.ink.color)
                .padding(.horizontal, WordLoopSpacing.safeWide)
                .padding(.vertical, WordLoopSpacing.safe)
        }
        .environment(\.posterPalette, palette)
    }
}

public struct MonoLabel: View {
    private let text: String
    private let color: Color?
    @Environment(\.posterPalette) private var palette

    public init(_ text: String, color: Color? = nil) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text.uppercased())
            .font(WordLoopTypography.label())
            .tracking(1.2)
            .foregroundStyle(color ?? palette.ink.color)
    }
}

public struct ModeSwitch: View {
    public let options: [String]
    @Binding private var selection: String
    private let accessibilityLabel: String
    private let accessibilityIdentifierPrefix: String?
    @Environment(\.posterPalette) private var palette

    public init(
        options: [String],
        selection: Binding<String>,
        accessibilityLabel: String,
        accessibilityIdentifierPrefix: String? = nil
    ) {
        self.options = options
        _selection = selection
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifierPrefix = accessibilityIdentifierPrefix
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Text(option)
                        .font(WordLoopTypography.label())
                        .padding(.horizontal, WordLoopSpacing.sm)
                        .frame(minHeight: WordLoopSpacing.minimumHit)
                        .foregroundStyle(
                            selection == option
                                ? palette.background.color
                                : palette.ink.color.opacity(WordLoopLayerOpacity.modeUnselectedText)
                        )
                        .background(selection == option ? palette.ink.color : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option)
                .accessibilityValue(selection == option ? "Selected" : "Not selected")
                .accessibilityAddTraits(selection == option ? .isSelected : [])
                .accessibilityIdentifier(identifier(for: option))
            }
        }
        .padding(3)
        .background(palette.ink.color.opacity(WordLoopLayerOpacity.modeTrack), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func identifier(for option: String) -> String {
        guard let accessibilityIdentifierPrefix else { return "" }
        return "\(accessibilityIdentifierPrefix).\(option.lowercased())"
    }
}

public enum PosterButtonContent: Equatable, Sendable {
    case text(String)
    case icon(systemName: String)
    case iconAndText(systemName: String, text: String)
}

public struct PosterButton: View {
    private let content: PosterButtonContent
    private let accessibilityLabel: String
    private let action: () -> Void

    public init(_ content: PosterButtonContent, accessibilityLabel: String, action: @escaping () -> Void) {
        self.content = content
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Group {
                switch content {
                case .text(let text):
                    Text(text)
                case .icon(let systemName):
                    Image(systemName: systemName)
                case .iconAndText(let systemName, let text):
                    Label(text, systemImage: systemName)
                }
            }
            .font(WordLoopTypography.label(size: 11))
            .frame(minWidth: WordLoopSpacing.minimumHit, minHeight: WordLoopSpacing.minimumHit)
            .padding(.horizontal, WordLoopSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

public struct CourseCardModel: Equatable, Sendable {
    public let title: String
    public let metadata: String
    public let detail: String?
    public let badge: String?
    public let isSelected: Bool

    public init(title: String, metadata: String, detail: String? = nil, badge: String? = nil, isSelected: Bool = false) {
        self.title = title
        self.metadata = metadata
        self.detail = detail
        self.badge = badge
        self.isSelected = isSelected
    }
}

public struct CourseCard: View {
    private let model: CourseCardModel
    private let palette: PosterPalette
    private let accessibilityLabel: String
    private let action: () -> Void

    public init(model: CourseCardModel, palette: PosterPalette, accessibilityLabel: String, action: @escaping () -> Void) {
        self.model = model
        self.palette = palette
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: WordLoopSpacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.title).font(WordLoopTypography.title(size: 16, weight: .semibold))
                    Spacer(minLength: WordLoopSpacing.sm)
                    if let badge = model.badge { MonoLabel(badge) }
                }
                MonoLabel(model.metadata)
                    .opacity(WordLoopLayerOpacity.courseCardSecondaryText)
                if let detail = model.detail {
                    Text(detail)
                        .font(WordLoopTypography.body(size: 13))
                        .opacity(WordLoopLayerOpacity.courseCardSecondaryText)
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(palette.background.color.opacity(0.88), in: RoundedRectangle(cornerRadius: WordLoopRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: WordLoopRadius.card)
                    .stroke(
                        model.isSelected ? palette.accent.color : palette.ink.color.opacity(WordLoopLayerOpacity.courseCardBoundary),
                        lineWidth: model.isSelected ? WordLoopBorder.emphasized : WordLoopBorder.hairline
                    )
            }
            .overlay {
                if model.isSelected {
                    RoundedRectangle(cornerRadius: WordLoopRadius.card - 3)
                        .inset(by: 3)
                        .stroke(
                            palette.ink.color.opacity(WordLoopLayerOpacity.courseCardBoundary),
                            lineWidth: WordLoopBorder.hairline
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: WordLoopSpacing.minimumHit)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(model.isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(model.isSelected ? .isSelected : [])
    }
}

public enum SideDrawerEdge: Equatable, Sendable {
    case leading
    case trailing
}

public struct SideDrawer<Content: View>: View {
    private let edge: SideDrawerEdge
    private let palette: PosterPalette
    private let kicker: String?
    private let title: String
    private let closeAccessibilityLabel: String
    private let closeAccessibilityIdentifier: String
    private let isModal: Bool
    private let onClose: () -> Void
    private let content: Content

    public init(
        edge: SideDrawerEdge,
        palette: PosterPalette,
        kicker: String? = nil,
        title: String,
        closeAccessibilityLabel: String,
        closeAccessibilityIdentifier: String? = nil,
        isModal: Bool = true,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.edge = edge
        self.palette = palette
        self.kicker = kicker
        self.title = title
        self.closeAccessibilityLabel = closeAccessibilityLabel
        self.closeAccessibilityIdentifier = closeAccessibilityIdentifier ?? closeAccessibilityLabel
        self.isModal = isModal
        self.onClose = onClose
        self.content = content()
    }

    public var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                if edge == .trailing { Spacer(minLength: 0) }
                VStack(spacing: WordLoopSpacing.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: WordLoopSpacing.xs) {
                            if let kicker {
                                MonoLabel(kicker, color: palette.accessibleAccentText.color)
                            }
                            Text(title).font(WordLoopTypography.title())
                        }
                        Spacer()
                        PosterButton(.icon(systemName: "xmark"), accessibilityLabel: closeAccessibilityLabel, action: onClose)
                            .accessibilityIdentifier(closeAccessibilityIdentifier)
                    }
                    content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(.horizontal, WordLoopSpacing.safe)
                .padding(.vertical, WordLoopSpacing.safeWide)
                .safeAreaPadding(.vertical)
                .frame(width: min(344, proxy.size.width * 0.86))
                .frame(maxHeight: .infinity)
                .foregroundStyle(palette.ink.color)
                .background(palette.background.color)
                .shadow(color: .black.opacity(WordLoopShadow.drawer.colorOpacity), radius: WordLoopShadow.drawer.radius)
                if edge == .leading { Spacer(minLength: 0) }
            }
            .background(.black.opacity(0.42))
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isModal ? .isModal : [])
    }
}

public struct ProgressTrack: View {
    private let progress: Double
    private let palette: PosterPalette
    private let accessibilityLabel: String
    private let explicitAccessibilityValue: String?

    public init(
        progress: Double,
        palette: PosterPalette,
        accessibilityLabel: String,
        accessibilityValue: String? = nil
    ) {
        self.progress = min(max(progress, 0), 1)
        self.palette = palette
        self.accessibilityLabel = accessibilityLabel
        self.explicitAccessibilityValue = accessibilityValue
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.ink.color.opacity(WordLoopLayerOpacity.progressBoundary))
                Capsule()
                    .fill(palette.accessibleAccentText.color)
                    .frame(width: proxy.size.width * progress)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(palette.accent.color)
                            .frame(height: 1)
                            .accessibilityHidden(true)
                    }
            }
        }
        .frame(height: 4)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(explicitAccessibilityValue ?? progress.formatted(.percent.precision(.fractionLength(0))))
    }
}

public struct ConfirmDialogModel: Equatable, Sendable {
    public let kicker: String
    public let title: String
    public let message: String
    public let cancelTitle: String
    public let confirmTitle: String
    public let errorMessage: String?

    public init(
        kicker: String,
        title: String,
        message: String,
        cancelTitle: String,
        confirmTitle: String,
        errorMessage: String? = nil
    ) {
        self.kicker = kicker
        self.title = title
        self.message = message
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.errorMessage = errorMessage
    }
}

public struct ConfirmDialog: View {
    private let model: ConfirmDialogModel
    private let palette: PosterPalette
    private let onCancel: () -> Void
    private let onConfirm: () -> Void
    private let accessibilityIdentifierPrefix: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        model: ConfirmDialogModel,
        palette: PosterPalette,
        accessibilityIdentifierPrefix: String? = nil,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.model = model
        self.palette = palette
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        self.accessibilityIdentifierPrefix = accessibilityIdentifierPrefix
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: WordLoopSpacing.sm) {
            MonoLabel(model.kicker, color: palette.accessibleAccentText.color)
            Text(model.title)
                .font(WordLoopTypography.title(size: 23))
                .optionalAccessibilityIdentifier(identifier("title"))
            Text(model.message)
                .font(WordLoopTypography.body(size: 13))
                .opacity(WordLoopLayerOpacity.dialogSecondaryText)
                .optionalAccessibilityIdentifier(identifier("message"))
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(WordLoopTypography.body(size: 13, weight: .semibold))
                    .foregroundStyle(palette.accessibleAccentText.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .optionalAccessibilityIdentifier(identifier("error"))
            }
            actions
        }
        .padding(WordLoopSpacing.safeWide)
        .frame(maxWidth: 320)
        .foregroundStyle(palette.ink.color)
        .background(palette.background.color, in: RoundedRectangle(cornerRadius: WordLoopRadius.dialog))
        .overlay {
            RoundedRectangle(cornerRadius: WordLoopRadius.dialog)
                .stroke(palette.ink.color.opacity(WordLoopLayerOpacity.dialogBoundary))
        }
        .shadow(color: .black.opacity(WordLoopShadow.dialog.colorOpacity), radius: WordLoopShadow.dialog.radius, y: WordLoopShadow.dialog.y)
        .padding(WordLoopSpacing.safeWide)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private var actions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: WordLoopSpacing.xs) {
                cancelButton.frame(maxWidth: .infinity)
                confirmButton.frame(maxWidth: .infinity)
            }
        } else {
            HStack(spacing: WordLoopSpacing.xs) {
                Spacer()
                cancelButton
                confirmButton
            }
        }
    }

    private var cancelButton: some View {
        PosterButton(.text(model.cancelTitle), accessibilityLabel: model.cancelTitle, action: onCancel)
            .overlay {
                RoundedRectangle(cornerRadius: WordLoopRadius.control)
                    .stroke(
                        palette.ink.color.opacity(WordLoopLayerOpacity.dialogBoundary),
                        lineWidth: WordLoopBorder.hairline
                    )
            }
            .optionalAccessibilityIdentifier(identifier("cancel"))
    }

    private var confirmButton: some View {
        Button(model.confirmTitle, action: onConfirm)
            .font(WordLoopTypography.label(size: 11))
            .frame(minHeight: WordLoopSpacing.minimumHit)
            .padding(.horizontal, 13)
            .foregroundStyle(palette.background.color)
            .background(palette.accessibleAccentText.color, in: RoundedRectangle(cornerRadius: WordLoopRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: WordLoopRadius.control)
                    .stroke(palette.accent.color, lineWidth: WordLoopBorder.hairline)
            }
            .accessibilityLabel(model.confirmTitle)
            .optionalAccessibilityIdentifier(identifier("confirm"))
    }

    private func identifier(_ suffix: String) -> String? {
        accessibilityIdentifierPrefix.map { "\($0).\(suffix)" }
    }
}

public enum WaveformState: String, CaseIterable, Sendable {
    case idle
    case active
    case success
    case failure
}

public struct Waveform: View {
    private static let heights: [CGFloat] = [18, 30, 44, 54, 64, 54, 44, 30, 18]

    private let state: WaveformState
    private let palette: PosterPalette
    private let accessibilityLabel: String
    private let tint: WordLoopSRGB?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animated = false

    public init(
        state: WaveformState,
        palette: PosterPalette,
        accessibilityLabel: String,
        tint: WordLoopSRGB? = nil
    ) {
        self.state = state
        self.palette = palette
        self.accessibilityLabel = accessibilityLabel
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(Self.heights.enumerated()), id: \.offset) { index, height in
                Capsule()
                    .fill(color)
                    .frame(width: 5, height: height)
                    .scaleEffect(y: scale(for: index))
                    .opacity(opacity)
                    .animation(animation(for: index), value: animated)
            }
        }
        .frame(minWidth: WordLoopSpacing.minimumHit, minHeight: 64)
        .onAppear { animated = state == .active && !motionReduced }
        .onChange(of: reduceMotion) { _, _ in animated = state == .active && !motionReduced }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(state.rawValue)
    }

    private var color: Color {
        if let tint { return palette.accessibleStatusVisual(tint).color }
        return switch state {
        case .idle, .active: palette.ink.color
        case .success: palette.accessibleStatusVisual(.init(hex: 0x148263)).color
        case .failure: palette.accessibleStatusVisual(.init(hex: 0xc76857)).color
        }
    }

    private var opacity: Double {
        switch state {
        case .idle: 0.28
        case .failure: 1
        case .active, .success: 0.78
        }
    }

    private func scale(for index: Int) -> CGFloat {
        guard state == .active, !motionReduced else { return 1 }
        return animated ? (index.isMultiple(of: 2) ? 0.52 : 0.74) : 1
    }

    private func animation(for index: Int) -> Animation? {
        guard state == .active, !motionReduced else { return nil }
        return .easeInOut(duration: WordLoopMotion.waveformDuration)
            .delay(Double(index % 3) * -0.22)
            .repeatForever(autoreverses: true)
    }

    private var motionReduced: Bool {
        reduceMotion || ProcessInfo.processInfo.arguments.contains("-wordloop-fixture-reduce-motion")
    }
}
