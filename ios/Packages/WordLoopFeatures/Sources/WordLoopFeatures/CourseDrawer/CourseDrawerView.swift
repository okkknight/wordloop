import SwiftUI
import WordLoopDesignSystem

public struct CourseDrawerView: View {
    private var copy: WordLoopCopy { .current }
    private static let drawerMaximumWidth: CGFloat = 304
    private static let drawerWidthFraction: CGFloat = 0.78
    @Bindable private var store: CourseDrawerStore
    private let palette: PosterPalette
    private let onSelectCourse: (String) -> Void
    private let onRequestDownload: (String) -> Void
    @FocusState private var searchIsFocused: Bool
    @State private var isPanelVisible = false
    @State private var isDismissing = false

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
            ZStack(alignment: .leading) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(copy.selectCourse)
                    .accessibilityIdentifier("course-drawer.page")

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
                .accessibilityLabel(copy.closeCourseSelector)
                .accessibilityIdentifier("course-drawer.backdrop")

                coursePanel(width: drawerWidth(in: geometry.size.width))
                .offset(x: isPanelVisible ? 0 : -drawerWidth(in: geometry.size.width))
                .animation(.easeInOut(duration: WordLoopMotion.drawerDuration), value: isPanelVisible)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .onEnded { value in
                            guard value.translation.width < -72,
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
    }

    private func coursePanel(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            panelHeader
            drawerContent
                .frame(maxHeight: .infinity, alignment: .top)
        }
        // A compact mobile measure leaves a clear, tappable backdrop while
        // preserving enough line length for course titles and search.
        .padding(20)
        .frame(width: width, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(palette.ink.color)
        .background(palette.background.color)
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

    private func drawerWidth(in availableWidth: CGFloat) -> CGFloat {
        min(Self.drawerMaximumWidth, availableWidth * Self.drawerWidthFraction)
    }

    private var panelHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(copy.coursePackages)
                    .font(WordLoopTypography.label(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(palette.accent.color)
                Text(copy.selectCourse)
                    .font(WordLoopTypography.title(size: 26, weight: .bold))
                    .tracking(-1.04)
            }
            Spacer(minLength: 0)
            Button("×") { dismiss { store.dismiss(reason: .header) } }
                .font(WordLoopTypography.body(size: 30, weight: .regular))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .accessibilityLabel(copy.closeCourseSelector)
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
                        Text(copy.noMatchingCourse)
                            .font(WordLoopTypography.body(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, WordLoopSpacing.safe)
                            .accessibilityIdentifier("course-drawer.empty")
                    }
                }
                .padding(.bottom, WordLoopSpacing.safeWide)
            }
            .frame(maxHeight: .infinity)
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
                prompt: Text(copy.searchCourse)
                    .foregroundStyle(palette.ink.color.opacity(0.6))
            )
            .font(WordLoopTypography.body(size: 12, weight: .semibold))
            .focused($searchIsFocused)
            .autocorrectionDisabled(true)
            .courseDrawerSearchTraits()
            .accessibilityLabel(copy.searchCourse)
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
            .accessibilityValue(store.state.isExpanded(collection.id) ? CourseDrawerStatusCopy.currentLocale.expanded : CourseDrawerStatusCopy.currentLocale.collapsed)
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
            dismiss {
                store.selectCourse(course.id)
                onSelectCourse(course.id)
            }
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
        .accessibilityValue(course.isSelected ? CourseDrawerStatusCopy.currentLocale.current : CourseDrawerStatusCopy.currentLocale.notSelected)
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
