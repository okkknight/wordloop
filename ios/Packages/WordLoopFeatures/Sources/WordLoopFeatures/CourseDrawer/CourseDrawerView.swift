import SwiftUI
import WordLoopDesignSystem

public struct CourseDrawerView: View {
    @Bindable private var store: CourseDrawerStore
    private let palette: PosterPalette
    private let onSelectCourse: (String) -> Void
    private let onRequestDownload: (String) -> Void
    @FocusState private var searchIsFocused: Bool

    public init(store: CourseDrawerStore, palette: PosterPalette) {
        self.store = store
        self.palette = palette
        onSelectCourse = { _ in }
        onRequestDownload = { _ in }
    }

    init(
        store: CourseDrawerStore,
        palette: PosterPalette,
        onSelectCourse: @escaping (String) -> Void,
        onRequestDownload: @escaping (String) -> Void = { _ in }
    ) {
        self.store = store
        self.palette = palette
        self.onSelectCourse = onSelectCourse
        self.onRequestDownload = onRequestDownload
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("课程选择器")
                    .accessibilityIdentifier("course-drawer.page")

                coursePanel(width: min(344, geometry.size.width * 0.86))
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

    private func coursePanel(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            panelHeader
            drawerContent
        }
        // Direct `.course-panel`: 20px on the mobile reference, panel width
        // `min(344px, 86vw)`, its own poster background, and a right shadow.
        .padding(20)
        .frame(width: width, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(palette.ink.color)
        .background(palette.background.color)
        .shadow(color: .black.opacity(0.16), radius: 30, x: 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // Web `.panel-backdrop`: a 42% black veil over a 7px blur.
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.42))
                .ignoresSafeArea()
        }
    }

    private var panelHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("COURSE PACKAGES")
                    .font(WordLoopTypography.label(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(palette.accent.color)
                Text("选择课程")
                    .font(WordLoopTypography.title(size: 26, weight: .bold))
                    .tracking(-1.04)
            }
            Spacer(minLength: 0)
            Button("×") { store.dismiss(reason: .header) }
                .font(WordLoopTypography.body(size: 30, weight: .regular))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .accessibilityLabel("关闭课程选择器")
                .accessibilityIdentifier("course-drawer.close")
        }
        .padding(.bottom, 22)
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
            TextField(
                "",
                text: Binding(
                    get: { store.state.query },
                    set: { query in store.updateQuery(query) }
                ),
                prompt: Text("搜索课程")
                    .foregroundStyle(palette.ink.color.opacity(0.6))
            )
            .font(WordLoopTypography.body(size: 12, weight: .semibold))
            .focused($searchIsFocused)
            .autocorrectionDisabled(true)
            .courseDrawerSearchTraits()
            .accessibilityLabel("搜索课程")
            .accessibilityIdentifier("course-drawer.search")

        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
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
        .padding(.bottom, 18)
    }

    private func collectionSection(_ collection: CourseDrawerCollection) -> some View {
        VStack(spacing: 0) {
            Button {
                store.toggleCollection(collection.id)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(collection.label)
                            .font(WordLoopTypography.label(size: 8, weight: .bold))
                            .tracking(0.88)
                            .foregroundStyle(palette.accent.color)
                            .padding(.bottom, 5)
                        Text(collection.title)
                            .font(WordLoopTypography.title(size: 16, weight: .bold))
                            .tracking(-0.4)
                        Text(collection.subtitle)
                            .font(WordLoopTypography.label(size: 9))
                            .foregroundStyle(palette.ink.color.opacity(0.52))
                            .padding(.top, 4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    // Web renders a font glyph (`+` / `−`), not an SF Symbol.
                    Text(store.state.isExpanded(collection.id) ? "−" : "+")
                        .font(WordLoopTypography.body(size: 21, weight: .light))
                        .frame(width: 20, height: 20)
                        .foregroundStyle(palette.accent.color)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(collection.title)，\(collection.subtitle)")
            .accessibilityValue(store.state.isExpanded(collection.id) ? "已展开" : "已收起")
            .accessibilityIdentifier("course-drawer.collection.\(collection.id)")

            if store.state.isExpanded(collection.id) {
                VStack(spacing: 7) {
                    ForEach(collection.courses) { course in
                        VStack(alignment: .leading, spacing: WordLoopSpacing.xs) {
                            courseCard(course)
                            .disabled(!course.availability.canSelect)
                            .accessibilityIdentifier("course-drawer.course.\(course.id)")
                            if let actionTitle = course.availability.actionTitle {
                                PosterButton(.text(actionTitle), accessibilityLabel: "\(course.title)，\(actionTitle)") {
                                    store.requestDownload(course.id)
                                    onRequestDownload(course.id)
                                }
                                .accessibilityIdentifier("course-drawer.download.\(course.id)")
                            }
                        }
                    }
                }
                .padding(.horizontal, 3)
                .padding(.bottom, 14)
            }
        }
        .padding(.vertical, 0)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.ink.color.opacity(0.14))
                .frame(height: WordLoopBorder.hairline)
                .accessibilityHidden(true)
        }
    }

    private func courseCard(_ course: CourseDrawerCourse) -> some View {
        Button {
            store.selectCourse(course.id)
            onSelectCourse(course.id)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(course.title)
                    .font(WordLoopTypography.title(size: 16, weight: .semibold))
                    .tracking(-0.48)
                Text(course.subtitle)
                    .font(WordLoopTypography.label(size: 9, weight: .medium))
                    .foregroundStyle(palette.ink.color.opacity(0.60))
                    .padding(.top, 5)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(course.isSelected ? palette.accent.color : palette.ink.color.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: course.isSelected ? palette.accent.color.opacity(0.14) : .clear, radius: 0)
            .overlay {
                if course.isSelected {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(palette.accent.color.opacity(0.14), lineWidth: 3)
                }
            }
            .overlay(alignment: .topTrailing) {
                // Web exposes completion only as a top-right `× N` badge;
                // availability is not rendered into the card metadata.
                if let badge = course.completionBadge {
                    Text(badge)
                        .font(WordLoopTypography.label(size: 9, weight: .semibold))
                        .tracking(0.27)
                        .foregroundStyle(palette.ink.color.opacity(0.46))
                        .padding(.top, 11)
                        .padding(.trailing, 12)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 13))
        .accessibilityLabel(courseAccessibilityLabel(course))
        .accessibilityValue(course.isSelected ? "当前课程" : "未选择")
    }

    private func courseAccessibilityLabel(_ course: CourseDrawerCourse) -> String {
        var parts = [course.title, course.subtitle, course.availability.rawValue, course.selectionAccessibilityValue]
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
