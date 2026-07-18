public enum CourseDrawerDismissReason: String, Equatable, Sendable {
    case header
    case backdrop
    case swipe
    case selection
}

public enum CourseDrawerAction: Equatable, Sendable {
    case presented
    case dismissed(CourseDrawerDismissReason)
    case updatedQuery(String)
    case toggledCollection(String?)
    case selectedCourse(String)
    case requestedDownload(String)
}

public struct CourseDrawerViewState: Equatable, Sendable {
    public var collections: [CourseDrawerCollection]
    public var query: String
    public var expandedCollectionID: String?
    public var isPresented: Bool
    public var lastDismissReason: CourseDrawerDismissReason?

    public init(
        collections: [CourseDrawerCollection],
        query: String = "",
        expandedCollectionID: String? = nil,
        isPresented: Bool = false,
        lastDismissReason: CourseDrawerDismissReason? = nil
    ) {
        self.collections = collections
        self.query = query
        self.expandedCollectionID = expandedCollectionID
        self.isPresented = isPresented
        self.lastDismissReason = lastDismissReason
    }

    public var normalizedQuery: String {
        CourseDrawerSearch.normalized(query)
    }

    public func isExpanded(_ collectionID: String) -> Bool {
        !normalizedQuery.isEmpty || expandedCollectionID == collectionID
    }

    public static var baseline: CourseDrawerViewState {
        .init(
            collections: CourseDrawerFixtures.collections,
            expandedCollectionID: "modern-family-s01"
        )
    }

    public static func fixture(arguments: [String]) -> CourseDrawerViewState {
        var state = baseline

        if let query = value(after: "-wordloop-course-query", in: arguments) {
            state.query = query
        }
        if arguments.contains("-wordloop-course-empty") {
            state.query = "no-such-course-fixture"
        }
        if arguments.contains("-wordloop-course-collapsed") {
            state.expandedCollectionID = nil
        }
        if let expandedID = value(after: "-wordloop-course-expanded", in: arguments) {
            state.expandedCollectionID = state.collections.contains(where: { $0.id == expandedID }) ? expandedID : nil
        }
        if let rawCount = value(after: "-wordloop-course-completion", in: arguments),
           let count = Int(rawCount) {
            state.setCompletionCount(count, for: "modern-family-s01e02")
        }
        if arguments.contains("-wordloop-course-drawer") || arguments.contains("-wordloop-course-presented") {
            state.isPresented = true
        }
        return state
    }

    public mutating func setCompletionCount(_ count: Int, for courseID: String) {
        for collectionIndex in collections.indices {
            guard let courseIndex = collections[collectionIndex].courses.firstIndex(where: { $0.id == courseID }) else {
                continue
            }
            collections[collectionIndex].courses[courseIndex].completionCount = count
            return
        }
    }

    private static func value(after key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
