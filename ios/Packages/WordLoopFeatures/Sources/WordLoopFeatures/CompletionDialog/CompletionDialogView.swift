import SwiftUI
import WordLoopDesignSystem

public struct CompletionDialogView: View {
    @Bindable private var store: CompletionDialogStore
    private let palette: PosterPalette
    private let onChooseCourse: () -> Void
    private let onRestartCourse: ((String) -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        store: CompletionDialogStore,
        palette: PosterPalette,
        onChooseCourse: @escaping () -> Void,
        onRestartCourse: ((String) -> Void)? = nil
    ) {
        self.store = store
        self.palette = palette
        self.onChooseCourse = onChooseCourse
        self.onRestartCourse = onRestartCourse
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.48))
                .ignoresSafeArea()
                .accessibilityHidden(true)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView { dialog.padding(.vertical, WordLoopSpacing.safeWide) }
                        .scrollIndicators(.hidden)
                } else {
                    dialog
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("completion-dialog.page")
    }

    private var dialog: some View {
        ConfirmDialog(
            model: .init(
                kicker: store.state.kind.kicker,
                title: store.state.kind.title,
                message: store.state.kind.message,
                cancelTitle: store.state.kind.cancelTitle,
                confirmTitle: store.state.kind.confirmTitle,
                errorMessage: store.state.errorMessage
            ),
            palette: palette,
            accessibilityIdentifierPrefix: "completion-dialog",
            onCancel: cancel,
            onConfirm: restart
        )
        .accessibilityLabel(store.state.kind.accessibilityLabel)
    }

    private func cancel() {
        if store.state.kind == .courseCompleted {
            store.chooseCourse()
            onChooseCourse()
        } else {
            store.cancel()
        }
    }

    private func restart() {
        if let onRestartCourse {
            onRestartCourse(store.state.courseID)
        } else {
            store.requestRestart()
        }
    }
}
