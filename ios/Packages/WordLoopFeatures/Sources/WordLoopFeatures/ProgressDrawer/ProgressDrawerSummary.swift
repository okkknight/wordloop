public struct ProgressDrawerSummary: Equatable, Sendable {
    public let courseTitle: String
    public let totalItemCount: Int
    public let maxStudyCount: Int
    public let totalStudies: Int
    public let masteredCount: Int

    public init(
        courseTitle: String,
        totalItemCount: Int,
        totalStudies: Int,
        masteredCount: Int
    ) {
        let safeItemCount = min(max(0, totalItemCount), Int.max / 3)
        let maximumStudies = safeItemCount * 3
        self.courseTitle = courseTitle
        self.totalItemCount = safeItemCount
        maxStudyCount = 3
        self.totalStudies = min(max(totalStudies, 0), maximumStudies)
        self.masteredCount = min(max(masteredCount, 0), safeItemCount)
    }

    public var maximumStudies: Int { totalItemCount * maxStudyCount }
    public var learningCount: Int { totalItemCount - masteredCount }
    public var progressFraction: Double {
        guard maximumStudies > 0 else { return 0 }
        return Double(totalStudies) / Double(maximumStudies)
    }
    public var totalStudiesLabel: String { "\(totalStudies) / \(maximumStudies)" }
}
