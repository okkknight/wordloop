import SwiftUI
import WordLoopDesignSystem

public struct ProgressDrawerView: View {
    private static let drawerMaximumWidth: CGFloat = 304
    private static let drawerWidthFraction: CGFloat = 0.78
    @Bindable private var store: ProgressDrawerStore
    private let palette: PosterPalette
    @FocusState private var searchIsFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(store: ProgressDrawerStore, palette: PosterPalette) {
        self.store = store
        self.palette = palette
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("学习进度")
                    .accessibilityIdentifier("progress-drawer.page")

                SideDrawer(
                    edge: .trailing,
                    palette: palette,
                    kicker: "YOUR PROGRESS",
                    title: store.state.summary.totalStudiesLabel,
                    closeAccessibilityLabel: "关闭学习进度",
                    closeAccessibilityIdentifier: "progress-drawer.close",
                    isModal: false,
                    onClose: { store.dismiss(reason: .header) }
                ) {
                    drawerContent
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .onEnded { value in
                            store.handleDrag(
                                horizontal: Double(value.translation.width),
                                vertical: Double(value.translation.height)
                            )
                        }
                )

                Button {
                    store.dismiss(reason: .backdrop)
                } label: {
                    Rectangle()
                        .fill(Color.black.opacity(0.001))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: max(0, geometry.size.width - drawerWidth(in: geometry.size.width)))
                .frame(maxHeight: .infinity)
                .accessibilityLabel("关闭学习进度")
                .accessibilityIdentifier("progress-drawer.backdrop")
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func drawerWidth(in availableWidth: CGFloat) -> CGFloat {
        min(Self.drawerMaximumWidth, availableWidth * Self.drawerWidthFraction)
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
                        Text("没有匹配的学习记录")
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
                accessibilityLabel: "课程学习进度",
                accessibilityValue: "已学习 \(store.state.summary.totalStudies) 次，共 \(store.state.summary.maximumStudies) 次"
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
        statistic("已掌握", value: store.state.summary.masteredCount, identifier: "progress-drawer.stats.mastered")
        statistic("学习中", value: store.state.summary.learningCount, identifier: "progress-drawer.stats.learning")
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
            .accessibilityLabel("\(label) \(value) 条")
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
            .accessibilityLabel("搜索学习记录")
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
