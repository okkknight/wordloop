import SwiftUI
import WordLoopDesignSystem

public struct CourseDrawerView: View {
    @Bindable private var store: CourseDrawerStore
    private let palette: PosterPalette
    private let onSelectCourse: (String) -> Void
    @FocusState private var searchIsFocused: Bool

    public init(store: CourseDrawerStore, palette: PosterPalette) {
        self.store = store
        self.palette = palette
        onSelectCourse = { _ in }
    }

    init(
        store: CourseDrawerStore,
        palette: PosterPalette,
        onSelectCourse: @escaping (String) -> Void
    ) {
        self.store = store
        self.palette = palette
        self.onSelectCourse = onSelectCourse
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("课程选择器")
                    .accessibilityIdentifier("course-drawer.page")

                SideDrawer(
                    edge: .leading,
                    palette: palette,
                    kicker: "COURSE PACKAGES",
                    title: "选择课程",
                    closeAccessibilityLabel: "关闭课程选择器",
                    closeAccessibilityIdentifier: "course-drawer.close",
                    isModal: false,
                    onClose: { store.dismiss(reason: .header) }
                ) {
                    drawerContent
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
                .frame(width: max(0, geometry.size.width - min(344, geometry.size.width * 0.86)))
                .frame(maxHeight: .infinity)
                .accessibilityLabel("关闭课程选择器")
                .accessibilityIdentifier("course-drawer.backdrop")
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    private var drawerContent: some View {
        VStack(spacing: 0) {
            searchField
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.filteredCollections) { collection in
                        collectionSection(collection)
                    }
                    if store.filteredCollections.isEmpty {
                        Text("没有匹配的课程")
                            .font(WordLoopTypography.body(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, WordLoopSpacing.safe)
                            .accessibilityIdentifier("course-drawer.empty")
                    }
                }
                .padding(.bottom, WordLoopSpacing.safeWide)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("course-drawer.list")
        }
    }

    private var searchField: some View {
        HStack(spacing: WordLoopSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .accessibilityHidden(true)
            TextField(
                "",
                text: Binding(
                    get: { store.state.query },
                    set: { query in store.updateQuery(query) }
                ),
                prompt: Text("搜索课程")
                    .foregroundStyle(palette.ink.color)
            )
            .font(WordLoopTypography.body(size: 12, weight: .semibold))
            .focused($searchIsFocused)
            .autocorrectionDisabled(true)
            .courseDrawerSearchTraits()
            .accessibilityLabel("搜索课程")
            .accessibilityIdentifier("course-drawer.search")

            if !store.state.query.isEmpty {
                Button {
                    store.updateQuery("")
                    searchIsFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: WordLoopSpacing.minimumHit, height: WordLoopSpacing.minimumHit)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
                .accessibilityIdentifier("course-drawer.search-clear")
            }
        }
        .padding(.leading, WordLoopSpacing.sm)
        .frame(minHeight: WordLoopSpacing.minimumHit)
        .overlay {
            RoundedRectangle(cornerRadius: WordLoopRadius.control)
                .stroke(palette.ink.color, lineWidth: WordLoopBorder.hairline)
        }
        .padding(.top, WordLoopSpacing.safe)
        .padding(.bottom, WordLoopSpacing.md)
    }

    private func collectionSection(_ collection: CourseDrawerCollection) -> some View {
        VStack(spacing: 0) {
            Button {
                store.toggleCollection(collection.id)
            } label: {
                HStack(alignment: .center, spacing: WordLoopSpacing.sm) {
                    VStack(alignment: .leading, spacing: WordLoopSpacing.xxs) {
                        MonoLabel(collection.label, color: palette.accessibleAccentText.color)
                        Text(collection.title)
                            .font(WordLoopTypography.title(size: 16, weight: .bold))
                        Text(collection.subtitle)
                            .font(WordLoopTypography.label(size: 9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: store.state.isExpanded(collection.id) ? "minus" : "plus")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: WordLoopSpacing.minimumHit, height: WordLoopSpacing.minimumHit)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: WordLoopSpacing.minimumHit, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(collection.title)，\(collection.subtitle)")
            .accessibilityValue(store.state.isExpanded(collection.id) ? "已展开" : "已收起")
            .accessibilityIdentifier("course-drawer.collection.\(collection.id)")

            if store.state.isExpanded(collection.id) {
                VStack(spacing: WordLoopSpacing.xs) {
                    ForEach(collection.courses) { course in
                        CourseCard(
                            model: .init(
                                title: course.title,
                                metadata: course.subtitle,
                                badge: course.completionBadge,
                                isSelected: course.isSelected
                            ),
                            palette: palette,
                            accessibilityLabel: courseAccessibilityLabel(course),
                            action: {
                                store.selectCourse(course.id)
                                onSelectCourse(course.id)
                            }
                        )
                        .accessibilityIdentifier("course-drawer.course.\(course.id)")
                    }
                }
                .padding(.bottom, WordLoopSpacing.sm)
            }
        }
        .padding(.vertical, WordLoopSpacing.xxs)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.ink.color)
                .frame(height: WordLoopBorder.hairline)
                .accessibilityHidden(true)
        }
    }

    private func courseAccessibilityLabel(_ course: CourseDrawerCourse) -> String {
        var parts = [course.title, course.subtitle, course.selectionAccessibilityValue]
        if let completion = course.completionAccessibilityValue {
            parts.append(completion)
        }
        return parts.joined(separator: "，")
    }
}

private extension View {
    @ViewBuilder
    func courseDrawerSearchTraits() -> some View {
#if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .keyboardType(.default)
#else
        self
#endif
    }
}
