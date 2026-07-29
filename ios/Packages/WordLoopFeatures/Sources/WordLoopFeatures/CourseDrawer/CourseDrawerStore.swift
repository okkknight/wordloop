import Observation

@MainActor
@Observable
public final class CourseDrawerStore {
    public var state: CourseDrawerViewState
    public private(set) var lastAction: CourseDrawerAction?

    public init(state: CourseDrawerViewState = .baseline) {
        self.state = state
    }

    public var filteredCollections: [CourseDrawerCollection] {
        let query = state.normalizedQuery
        guard !query.isEmpty else { return state.collections }

        return state.collections.compactMap { collection in
            if collection.matches(query) {
                return collection
            }
            let courses = collection.courses.filter { $0.matches(query) }
            guard !courses.isEmpty else { return nil }
            var filtered = collection
            filtered.courses = courses
            return filtered
        }
    }

    public func present() {
        state.isPresented = true
        state.lastDismissReason = nil
        lastAction = .presented
    }

    public func dismiss(reason: CourseDrawerDismissReason) {
        state.isPresented = false
        state.lastDismissReason = reason
        lastAction = .dismissed(reason)
    }

    public func updateQuery(_ query: String) {
        state.query = query
        lastAction = .updatedQuery(query)
    }

    public func toggleCollection(_ collectionID: String) {
        guard state.collections.contains(where: { $0.id == collectionID }) else { return }
        state.expandedCollectionID = state.expandedCollectionID == collectionID ? nil : collectionID
        lastAction = .toggledCollection(state.expandedCollectionID)
    }

    public func selectCourse(_ courseID: String) {
        guard state.collections.contains(where: { collection in
            collection.courses.contains(where: { $0.id == courseID && $0.availability.canSelect })
        }) else { return }

        state.isPresented = false
        state.lastDismissReason = .selection
        lastAction = .selectedCourse(courseID)
    }

    public func requestDownload(_ courseID: String) {
        guard state.collections.contains(where: { collection in
            collection.courses.contains(where: { $0.id == courseID && $0.availability.actionTitle != nil })
        }) else { return }
        lastAction = .requestedDownload(courseID)
    }

    @discardableResult
    public func handleDrag(horizontal: Double, vertical: Double) -> Bool {
        guard horizontal < -72, abs(horizontal) > abs(vertical) else { return false }
        dismiss(reason: .swipe)
        return true
    }
}
