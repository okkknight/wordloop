import Foundation

public enum CourseDrawerAvailability: String, Equatable, Sendable {
    case builtIn = "BUILT IN"
    case downloaded = "DOWNLOADED"
    case download = "DOWNLOAD"
    case downloading = "DOWNLOADING"
    case preparing = "PREPARING"
    case update = "UPDATE"
    case offline = "OFFLINE"
    case tryAgain = "TRY AGAIN"
    case freeUpSpace = "FREE UP SPACE"
    case updateApp = "UPDATE APP"

    var canSelect: Bool {
        self == .builtIn || self == .downloaded || self == .update
    }

    var actionTitle: String? {
        switch self {
        case .download, .update, .tryAgain, .offline, .freeUpSpace:
            rawValue
        default:
            nil
        }
    }
}

public struct CourseDrawerCourse: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public var completionCount: Int {
        didSet { completionCount = max(0, completionCount) }
    }
    public var isSelected: Bool
    public var availability: CourseDrawerAvailability

    public init(
        id: String,
        title: String,
        subtitle: String,
        completionCount: Int = 0,
        isSelected: Bool = false,
        availability: CourseDrawerAvailability = .builtIn
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.completionCount = max(0, completionCount)
        self.isSelected = isSelected
        self.availability = availability
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
