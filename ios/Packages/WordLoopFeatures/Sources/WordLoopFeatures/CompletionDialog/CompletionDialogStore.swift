import Observation

public enum CompletionDialogAction: Equatable, Sendable {
    case presented(CompletionDialogKind)
    case cancelled
    case selectedCourse
    case requestedRestart(String)
}

@MainActor
@Observable
public final class CompletionDialogStore {
    public var state: CompletionDialogViewState
    public private(set) var lastAction: CompletionDialogAction?

    public init(state: CompletionDialogViewState = .init()) {
        self.state = state
    }

    public func present(
        kind: CompletionDialogKind,
        courseID: String = CompletionDialogViewState.fixtureCourseID,
        errorMessage: String? = nil
    ) {
        state = .init(
            kind: kind,
            courseID: courseID,
            errorMessage: errorMessage,
            isPresented: true
        )
        lastAction = .presented(kind)
    }

    public func cancel() {
        guard state.isPresented else { return }
        state.isPresented = false
        lastAction = .cancelled
    }

    public func chooseCourse() {
        guard state.isPresented else { return }
        state.isPresented = false
        lastAction = .selectedCourse
    }

    public func requestRestart() {
        guard state.isPresented, !state.courseID.isEmpty else { return }
        state.isPresented = false
        lastAction = .requestedRestart(state.courseID)
    }
}
