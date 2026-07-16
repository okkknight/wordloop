import Observation

@MainActor
@Observable
public final class ProgressDrawerStore {
    public var state: ProgressDrawerViewState
    public private(set) var lastAction: ProgressDrawerAction?

    public init(state: ProgressDrawerViewState = .sentenceBaseline) {
        self.state = state
    }

    public var filteredEntries: [ProgressDrawerEntry] {
        state.filteredEntries
    }

    public func present() {
        state.isPresented = true
        state.lastDismissReason = nil
        lastAction = .presented
    }

    public func dismiss(reason: ProgressDrawerDismissReason) {
        state.isPresented = false
        state.lastDismissReason = reason
        lastAction = .dismissed(reason)
    }

    public func updateQuery(_ query: String) {
        state.query = query
        lastAction = .updatedQuery(query)
    }

    @discardableResult
    public func handleDrag(horizontal: Double, vertical: Double) -> Bool {
        guard horizontal > 72, abs(horizontal) > abs(vertical) else { return false }
        dismiss(reason: .swipe)
        return true
    }
}
