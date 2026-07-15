import Foundation

public struct CourseDrawerCourse: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public var completionCount: Int {
        didSet { completionCount = max(0, completionCount) }
    }
    public var isSelected: Bool

    public init(
        id: String,
        title: String,
        subtitle: String,
        completionCount: Int = 0,
        isSelected: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.completionCount = max(0, completionCount)
        self.isSelected = isSelected
    }

    public var completionBadge: String? {
        completionCount > 0 ? "× \(completionCount)" : nil
    }

    public var completionAccessibilityValue: String? {
        completionCount > 0 ? "已完成 \(completionCount) 次" : nil
    }

    public var selectionAccessibilityValue: String {
        isSelected ? "当前课程" : "未选择"
    }

    func matches(_ query: String) -> Bool {
        CourseDrawerSearch.matches(query, fields: [title, subtitle])
    }
}

public struct CourseDrawerCollection: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let title: String
    public let subtitle: String
    public var courses: [CourseDrawerCourse]

    public init(
        id: String,
        label: String,
        title: String,
        subtitle: String,
        courses: [CourseDrawerCourse]
    ) {
        self.id = id
        self.label = label
        self.title = title
        self.subtitle = subtitle
        self.courses = courses
    }

    func matches(_ query: String) -> Bool {
        CourseDrawerSearch.matches(query, fields: [label, title, subtitle])
    }
}

enum CourseDrawerSearch {
    static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func matches(_ normalizedQuery: String, fields: [String]) -> Bool {
        fields.contains { $0.lowercased().contains(normalizedQuery) }
    }
}
