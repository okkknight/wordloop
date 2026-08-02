import SwiftUI
import WordLoopDesignSystem

public struct ProgressDrawerView: View {
    private var copy: ProgressDrawerCopy { .current }
    private var statsCopy: ProgressDrawerStatsCopy { .current }
    private static let drawerMaximumWidth: CGFloat = 304
    private static let drawerWidthFraction: CGFloat = 0.78
    @Bindable private var store: ProgressDrawerStore
    private let palette: PosterPalette
    private let onDeleteAllData: (@MainActor () async throws -> Void)?
    @FocusState private var searchIsFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsDeleteConfirmation = false
    @State private var dataDeletionError: String?
    @State private var isPanelVisible = false
    @State private var isDismissing = false

    public init(
        store: ProgressDrawerStore,
        palette: PosterPalette,
        onDeleteAllData: (@MainActor () async throws -> Void)? = nil
    ) {
        self.store = store
        self.palette = palette
        self.onDeleteAllData = onDeleteAllData
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(copy.page)
                    .accessibilityIdentifier("progress-drawer.page")

                drawerBackdrop

                Button {
                    dismiss { store.dismiss(reason: .backdrop) }
                } label: {
                    Rectangle()
                        .fill(Color.black.opacity(0.001))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(copy.close)
                .accessibilityIdentifier("progress-drawer.backdrop")

                SideDrawer(
                    edge: .trailing,
                    palette: palette,
                    kicker: copy.kicker,
                    title: store.state.summary.totalStudiesLabel,
                    closeAccessibilityLabel: copy.close,
                    closeAccessibilityIdentifier: "progress-drawer.close",
                    isModal: false,
                    isPanelVisible: isPanelVisible,
                    onClose: { dismiss { store.dismiss(reason: .header) } }
                ) {
                    drawerContent
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .onEnded { value in
                            guard value.translation.width > 72,
                                  abs(value.translation.width) > abs(value.translation.height) else { return }
                            dismiss { store.dismiss(reason: .swipe) }
                        }
                )

            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .onAppear {
            isDismissing = false
            isPanelVisible = true
        }
        .onDisappear { isPanelVisible = false }
        .alert(copy.deleteQuestion, isPresented: $showsDeleteConfirmation) {
            Button(copy.cancel, role: .cancel) {}
            Button(copy.delete, role: .destructive) {
                Task { await deleteAllData() }
            }
        } message: {
            Text(copy.deleteQuestion)
        }
        .alert(copy.deleteError, isPresented: Binding(
            get: { dataDeletionError != nil },
            set: { if !$0 { dataDeletionError = nil } }
        )) {
            Button(copy.acknowledge, role: .cancel) {}
        } message: {
            Text(dataDeletionError ?? copy.retryNetwork)
        }
    }

    private func drawerWidth(in availableWidth: CGFloat) -> CGFloat {
        min(Self.drawerMaximumWidth, availableWidth * Self.drawerWidthFraction)
    }

    private var drawerBackdrop: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(Color.black.opacity(0.42))
            .ignoresSafeArea()
            .opacity(isPanelVisible ? 1 : 0)
            .animation(.easeInOut(duration: WordLoopMotion.drawerDuration), value: isPanelVisible)
            .accessibilityHidden(true)
    }

    private func dismiss(_ action: @escaping @MainActor () -> Void) {
        guard !isDismissing else { return }
        isDismissing = true
        isPanelVisible = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(WordLoopMotion.drawerDuration * 1_000_000_000))
            action()
        }
    }

    private var drawerContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            summary
            searchField
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.filteredEntries) { entry in
                        entryRow(entry)
                    }
                    if store.filteredEntries.isEmpty {
                        Text(copy.empty)
                            .font(WordLoopTypography.body(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, WordLoopSpacing.safe)
                            .accessibilityIdentifier("progress-drawer.empty")
                    }
                }
                .padding(.bottom, WordLoopSpacing.safeWide)
            }
            .frame(maxHeight: .infinity)
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("progress-drawer.list")

            if onDeleteAllData != nil {
                Button(copy.delete) {
                    showsDeleteConfirmation = true
                }
                .font(WordLoopTypography.label(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(palette.ink.color.opacity(0.58))
                .buttonStyle(.plain)
                .padding(.top, 2)
                .accessibilityLabel(copy.delete)
                .accessibilityIdentifier("progress-drawer.delete-data")
            }
        }
    }

    @MainActor
    private func deleteAllData() async {
        guard let onDeleteAllData else { return }
        do {
            try await onDeleteAllData()
            dismiss { store.dismiss(reason: .header) }
        } catch {
            dataDeletionError = copy.retryNetwork
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: WordLoopSpacing.xs) {
            Text(store.state.summary.courseTitle)
                .font(WordLoopTypography.body(size: 13, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("progress-drawer.course")

            ProgressTrack(
                progress: store.state.summary.progressFraction,
                palette: palette,
                accessibilityLabel: statsCopy.progress,
                accessibilityValue: "\(statsCopy.studied) \(store.state.summary.totalStudies), \(store.state.summary.maximumStudies)"
            )
            .accessibilityIdentifier("progress-drawer.track")

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: WordLoopSpacing.xxs) { statistics }
                } else {
                    HStack(spacing: WordLoopSpacing.md) { statistics }
                }
            }
        }
    }

    @ViewBuilder
    private var statistics: some View {
        statistic(statsCopy.mastered, value: store.state.summary.masteredCount, identifier: "progress-drawer.stats.mastered")
        statistic(statsCopy.learning, value: store.state.summary.learningCount, identifier: "progress-drawer.stats.learning")
    }

    private func statistic(_ label: String, value: Int, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(WordLoopTypography.title(size: 16, weight: .bold))
            Text(label)
                .font(WordLoopTypography.label(size: 9, weight: .regular))
                .opacity(0.54)
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.ink.color.opacity(0.14), lineWidth: 1))
            .background(palette.background.color.opacity(0.88), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel("\(label) \(value)")
            .accessibilityIdentifier(identifier)
    }

    private var searchField: some View {
        HStack(spacing: WordLoopSpacing.xs) {
            TextField(
                "",
                text: Binding(
                    get: { store.state.query },
                    set: { store.updateQuery($0) }
                ),
                prompt: Text(store.state.searchPlaceholder).foregroundStyle(palette.ink.color)
            )
            .font(WordLoopTypography.body(size: 12, weight: .semibold))
            .focused($searchIsFocused)
            .autocorrectionDisabled(true)
            .progressDrawerSearchTraits()
            .accessibilityLabel(copy.search)
            .accessibilityIdentifier("progress-drawer.search")

        }
        .frame(height: 36)
        .padding(.horizontal, 12)
        .overlay {
            RoundedRectangle(cornerRadius: WordLoopRadius.control)
                .stroke(searchIsFocused ? palette.accent.color : palette.ink.color.opacity(0.24), lineWidth: WordLoopBorder.hairline)
        }
        .overlay {
            if searchIsFocused {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(palette.accent.color.opacity(0.12), lineWidth: 3)
            }
        }
    }

    private func entryRow(_ entry: ProgressDrawerEntry) -> some View {
        HStack(alignment: .top, spacing: WordLoopSpacing.xs) {
            VStack(alignment: .leading, spacing: WordLoopSpacing.xxs) {
                Text(entry.primaryText)
                    .font(WordLoopTypography.body(size: 13, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.secondaryText)
                    .font(WordLoopTypography.body(size: 12))
                    .opacity(WordLoopLayerOpacity.progressSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: WordLoopSpacing.xs)
            Text(entry.countLabel)
                .font(WordLoopTypography.label(size: 10))
                .foregroundStyle(entry.isMastered ? palette.accessibleAccentText.color : palette.ink.color)
                .opacity(entry.isMastered ? 1 : WordLoopLayerOpacity.progressSecondaryText)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.ink.color.opacity(WordLoopLayerOpacity.progressBoundary))
                .frame(height: WordLoopBorder.hairline)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.accessibilityLabel)
        .accessibilityIdentifier("progress-drawer.entry.\(entry.id)")
    }
}

private extension View {
    @ViewBuilder
    func progressDrawerSearchTraits() -> some View {
#if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .keyboardType(.default)
#else
        self
#endif
    }
}
