import Foundation

public enum ProgressStudyModeDTO: String, Codable, CaseIterable, Sendable {
    case listen
    case `repeat`
}

public struct ProgressQueryDTO: Equatable, Sendable {
    public let userID: String
    public let mode: ProgressStudyModeDTO
    public let courseID: String?

    public init(userID: String, mode: ProgressStudyModeDTO, courseID: String? = nil) {
        self.userID = userID
        self.mode = mode
        self.courseID = courseID
    }

    public var queryItems: [URLQueryItem] {
        var items = [
            URLQueryItem(name: "userId", value: userID),
            URLQueryItem(name: "mode", value: mode.rawValue),
        ]
        if let courseID { items.append(URLQueryItem(name: "courseId", value: courseID)) }
        return items
    }
}

public struct WordProgressDTO: Codable, Equatable, Sendable {
    public let word: String
    public let studyCount: Int
}

public struct CourseItemProgressDTO: Codable, Equatable, Sendable {
    public let itemId: String
    public let studyCount: Int
}

public struct CourseCompletionDTO: Codable, Equatable, Sendable {
    public let courseId: String
    public let completionCount: Int
}

public struct WordProgressSnapshotDTO: Codable, Equatable, Sendable {
    public let progress: [WordProgressDTO]
    public let completions: [CourseCompletionDTO]
    public let recentCourseId: String?
}

public struct CourseProgressSnapshotDTO: Codable, Equatable, Sendable {
    public let progress: [CourseItemProgressDTO]
}

public struct WordProgressRequestDTO: Codable, Equatable, Sendable {
    public let userId: String
    public let mode: ProgressStudyModeDTO
    public let clientEventId: String
    public let word: String
    public let markMastered: Bool?

    public init(userId: String, mode: ProgressStudyModeDTO, clientEventId: String, word: String, markMastered: Bool = false) {
        self.userId = userId
        self.mode = mode
        self.clientEventId = clientEventId
        self.word = word
        self.markMastered = markMastered ? true : nil
    }
}

public struct CourseProgressRequestDTO: Codable, Equatable, Sendable {
    public let userId: String
    public let mode: ProgressStudyModeDTO
    public let clientEventId: String
    public let courseId: String
    public let itemId: String
    public let markMastered: Bool?

    public init(userId: String, mode: ProgressStudyModeDTO, clientEventId: String, courseId: String, itemId: String, markMastered: Bool = false) {
        self.userId = userId
        self.mode = mode
        self.clientEventId = clientEventId
        self.courseId = courseId
        self.itemId = itemId
        self.markMastered = markMastered ? true : nil
    }
}

public struct SelectCourseRequestDTO: Codable, Equatable, Sendable {
    public let userId: String
    public let mode: ProgressStudyModeDTO
    public let courseId: String
    public let selectCourse: Bool

    public init(userId: String, mode: ProgressStudyModeDTO, courseId: String) {
        self.userId = userId
        self.mode = mode
        self.courseId = courseId
        self.selectCourse = true
    }
}

public struct ResetCourseRequestDTO: Codable, Equatable, Sendable {
    public let userId: String
    public let mode: ProgressStudyModeDTO
    public let courseId: String
    public let resetCourse: Bool

    public init(userId: String, mode: ProgressStudyModeDTO, courseId: String) {
        self.userId = userId
        self.mode = mode
        self.courseId = courseId
        self.resetCourse = true
    }
}

public struct CompleteCourseRequestDTO: Codable, Equatable, Sendable {
    public let userId: String
    public let mode: ProgressStudyModeDTO
    public let clientEventId: String
    public let courseId: String
    public let completeCourse: Bool

    public init(userId: String, mode: ProgressStudyModeDTO, clientEventId: String, courseId: String) {
        self.userId = userId
        self.mode = mode
        self.clientEventId = clientEventId
        self.courseId = courseId
        self.completeCourse = true
    }
}

public struct WordProgressResponseDTO: Codable, Equatable, Sendable {
    public let word: String
    public let studyCount: Int
}

public struct CourseProgressResponseDTO: Codable, Equatable, Sendable {
    public let itemId: String
    public let studyCount: Int
}

public struct SelectCourseResponseDTO: Codable, Equatable, Sendable {
    public let recentCourseId: String
}

public struct ResetCourseResponseDTO: Codable, Equatable, Sendable {
    public let courseId: String
    public let reset: Bool
}

public struct CompleteCourseResponseDTO: Codable, Equatable, Sendable {
    public let courseId: String
    public let completionCount: Int
}

public struct ProgressErrorDTO: Codable, Equatable, Sendable {
    public let error: String
}
