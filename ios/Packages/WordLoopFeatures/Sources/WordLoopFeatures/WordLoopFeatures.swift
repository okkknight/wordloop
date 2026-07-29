import SwiftUI
import WordLoopAudio
import WordLoopContent
import WordLoopCore
import WordLoopDesignSystem
import WordLoopProgress
import WordLoopRealtime

/// Compile-time marker for the WordLoopFeatures module boundary.
public enum WordLoopFeaturesModule {
    public static let name = "WordLoopFeatures"

    @discardableResult
    public static func prepareDesignSystem() -> WordLoopFontRegistrationResult {
        WordLoopFontRegistry.registerBundledFonts()
    }

    @MainActor
    public static func makeLocalIntegrationStudyStore() throws -> StudyStore {
        let source = try BundledCourseSource.live()
        let courseRepository = CourseRepository(source: source)
        let audioPlayer = try AudioPlayer.live()
        let progressRepository = TemporaryProgressRepository()
        return StudyStore(
            courses: .live(repository: courseRepository),
            audio: .live(player: audioPlayer),
            progress: .temporary(repository: progressRepository)
        )
    }

}

public struct DesignSystemGalleryView: View {
    @State private var mode = "LISTEN"
    @State private var showsDialog = false
    @State private var showsDrawer = false

    private let palette = PosterPalette.defaultPalette

    public init() {}

    public var body: some View {
        PosterBackground(palette: palette) {
            ScrollView {
                VStack(alignment: .leading, spacing: WordLoopSpacing.safeWide) {
                    header
                    paletteGrid
                    controls
                    components
                }
                .padding(.vertical, WordLoopSpacing.safeWide)
            }
            .scrollIndicators(.hidden)
        }
        .overlay {
            if showsDialog {
                Color.black.opacity(0.34).ignoresSafeArea()
                ConfirmDialog(
                    model: .init(
                        kicker: "FIXTURE DIALOG",
                        title: "Visual foundation",
                        message: "This is a presentation-only fixture, not a product flow.",
                        cancelTitle: "CANCEL",
                        confirmTitle: "CONFIRM"
                    ),
                    palette: palette,
                    onCancel: { showsDialog = false },
                    onConfirm: { showsDialog = false }
                )
                .accessibilityIdentifier("design-system.dialog")
            }
            if showsDrawer {
                SideDrawer(
                    edge: .leading,
                    palette: palette,
                    title: "FIXTURE DRAWER",
                    closeAccessibilityLabel: "Close fixture drawer",
                    onClose: { showsDrawer = false }
                ) {
                    Text("Presentation container only")
                        .font(WordLoopTypography.body())
                }
                .accessibilityIdentifier("design-system.drawer")
            }
        }
        .accessibilityIdentifier("design-system.gallery")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: WordLoopSpacing.xs) {
            MonoLabel("DESIGN SYSTEM", color: palette.accessibleAccentText.color)
            Text("Native fixture gallery")
                .font(WordLoopTypography.title(size: 34))
            Text("iPhone visual primitives · no product state")
                .font(WordLoopTypography.body(size: 13))
                .opacity(0.64)
        }
        .accessibilityElement(children: .combine)
    }

    private var paletteGrid: some View {
        VStack(alignment: .leading, spacing: WordLoopSpacing.sm) {
            MonoLabel("SIX POSTER PALETTES")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: WordLoopSpacing.xs), count: 3), spacing: WordLoopSpacing.xs) {
                ForEach(PosterPalette.all) { item in
                    ZStack(alignment: .bottomLeading) {
                        item.background.color
                        Circle()
                            .fill(item.accent.color)
                            .frame(width: 28, height: 28)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(10)
                            .accessibilityHidden(true)
                        Text(item.id.uppercased())
                            .font(WordLoopTypography.label(size: 8))
                            .foregroundStyle(item.ink.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(8)
                    }
                    .frame(height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: WordLoopRadius.control))
                    .overlay { RoundedRectangle(cornerRadius: WordLoopRadius.control).stroke(item.ink.color.opacity(0.18)) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Palette \(item.order + 1), \(item.id)")
                    .accessibilityIdentifier("design-system.palette.\(item.id)")
                }
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: WordLoopSpacing.sm) {
            MonoLabel("CONTROLS")
            ModeSwitch(options: ["LISTEN", "REPEAT"], selection: $mode, accessibilityLabel: "Fixture mode")
                .accessibilityIdentifier("design-system.mode-switch")
            HStack {
                PosterButton(.iconAndText(systemName: "play.fill", text: "PLAY"), accessibilityLabel: "Fixture play") {}
                PosterButton(.text("SHOW DIALOG"), accessibilityLabel: "Show fixture dialog") { showsDialog = true }
                PosterButton(.text("DRAWER"), accessibilityLabel: "Show fixture drawer") { showsDrawer = true }
            }
        }
    }

    private var components: some View {
        VStack(alignment: .leading, spacing: WordLoopSpacing.md) {
            MonoLabel("COMPONENTS")
            CourseCard(
                model: .init(title: "Course card", metadata: "12 ITEMS", detail: "Presentation-only fixture", badge: "× 2", isSelected: true),
                palette: palette,
                accessibilityLabel: "Selected fixture course"
            ) {}
            ProgressTrack(progress: 0.64, palette: palette, accessibilityLabel: "Fixture progress")
                .accessibilityIdentifier("design-system.progress")
            HStack {
                ForEach(WaveformState.allCases, id: \.rawValue) { state in
                    VStack {
                        Waveform(state: state, palette: palette, accessibilityLabel: "\(state.rawValue) waveform")
                            .scaleEffect(0.55)
                            .frame(width: 56, height: 44)
                        MonoLabel(state.rawValue)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityIdentifier("design-system.waveforms")
        }
    }
}
