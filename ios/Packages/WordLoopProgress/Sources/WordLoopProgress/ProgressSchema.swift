import Foundation
import SwiftData

public enum ProgressEventKind: String, Codable, CaseIterable, Sendable {
    case increment
    case master
    case reset
}

public enum ProgressOutboxState: String, Codable, CaseIterable, Sendable {
    case pending
    case sending
    case acknowledged
}

enum ProgressStableKey {
    static func make(_ components: String...) -> String {
        components.map { "\($0.utf8.count):\($0)" }.joined()
    }
}

@Model
public final class StudyIdentity {
    @Attribute(.unique) public var identityID: String
    public var userID: String
    public var username: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(identityID: String, userID: String, username: String?, createdAt: Date, updatedAt: Date) {
        self.identityID = identityID
        self.userID = userID
        self.username = username
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class ProgressRecord {
    @Attribute(.unique) public var recordID: String
    public var userID: String
    public var modeRawValue: String
    public var courseID: String
    public var entryID: String
    public var studyCount: Int
    public var updatedAt: Date

    public init(userID: String, modeRawValue: String, courseID: String, entryID: String, studyCount: Int, updatedAt: Date) {
        self.recordID = Self.makeID(userID: userID, modeRawValue: modeRawValue, courseID: courseID, entryID: entryID)
        self.userID = userID
        self.modeRawValue = modeRawValue
        self.courseID = courseID
        self.entryID = entryID
        self.studyCount = studyCount
        self.updatedAt = updatedAt
    }

    public static func makeID(userID: String, modeRawValue: String, courseID: String, entryID: String) -> String {
        ProgressStableKey.make(userID, modeRawValue, courseID, entryID)
    }
}

@Model
public final class ProgressEvent {
    @Attribute(.unique) public var clientEventID: String
    public var userID: String
    public var modeRawValue: String
    public var courseID: String
    public var entryID: String
    public var kindRawValue: String
    public var stateRawValue: String
    public var createdAt: Date
    public var lastAttemptAt: Date?
    public var acknowledgedAt: Date?
    public var attemptCount: Int

    public init(
        clientEventID: String,
        userID: String,
        modeRawValue: String,
        courseID: String,
        entryID: String,
        kindRawValue: String,
        stateRawValue: String,
        createdAt: Date,
        lastAttemptAt: Date? = nil,
        acknowledgedAt: Date? = nil,
        attemptCount: Int = 0
    ) {
        self.clientEventID = clientEventID
        self.userID = userID
        self.modeRawValue = modeRawValue
        self.courseID = courseID
        self.entryID = entryID
        self.kindRawValue = kindRawValue
        self.stateRawValue = stateRawValue
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
        self.acknowledgedAt = acknowledgedAt
        self.attemptCount = attemptCount
    }
}

@Model
public final class CourseCompletionRecord {
    @Attribute(.unique) public var recordID: String
    public var userID: String
    public var courseID: String
    public var completionCount: Int
    public var updatedAt: Date

    public init(userID: String, courseID: String, completionCount: Int, updatedAt: Date) {
        self.recordID = Self.makeID(userID: userID, courseID: courseID)
        self.userID = userID
        self.courseID = courseID
        self.completionCount = completionCount
        self.updatedAt = updatedAt
    }

    public static func makeID(userID: String, courseID: String) -> String {
        ProgressStableKey.make(userID, courseID)
    }
}

@Model
public final class CourseCompletionEvent {
    @Attribute(.unique) public var clientEventID: String
    public var userID: String
    public var courseID: String
    public var stateRawValue: String
    public var createdAt: Date
    public var lastAttemptAt: Date?
    public var acknowledgedAt: Date?
    public var attemptCount: Int

    public init(
        clientEventID: String,
        userID: String,
        courseID: String,
        stateRawValue: String,
        createdAt: Date,
        lastAttemptAt: Date? = nil,
        acknowledgedAt: Date? = nil,
        attemptCount: Int = 0
    ) {
        self.clientEventID = clientEventID
        self.userID = userID
        self.courseID = courseID
        self.stateRawValue = stateRawValue
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
        self.acknowledgedAt = acknowledgedAt
        self.attemptCount = attemptCount
    }
}

@Model
public final class CoursePreference {
    @Attribute(.unique) public var userID: String
    public var recentCourseID: String
    public var updatedAt: Date

    public init(userID: String, recentCourseID: String, updatedAt: Date) {
        self.userID = userID
        self.recentCourseID = recentCourseID
        self.updatedAt = updatedAt
    }
}

public enum WordLoopProgressSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] {
        [
            StudyIdentity.self,
            ProgressRecord.self,
            ProgressEvent.self,
            CourseCompletionRecord.self,
            CourseCompletionEvent.self,
            CoursePreference.self,
        ]
    }
}

public enum WordLoopProgressMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [WordLoopProgressSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum WordLoopProgressContainer {
    public static func makeInMemory() throws -> ModelContainer {
        try make(configuration: ModelConfiguration(
            "WordLoopProgress",
            schema: Schema(versionedSchema: WordLoopProgressSchemaV1.self),
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        ))
    }

    public static func makePersistent(storeURL: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: WordLoopProgressSchemaV1.self)
        let configuration = if let storeURL {
            ModelConfiguration(
                "WordLoopProgress",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        } else {
            ModelConfiguration(
                "WordLoopProgress",
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }
        return try make(configuration: configuration)
    }

    private static func make(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: WordLoopProgressSchemaV1.self),
            migrationPlan: WordLoopProgressMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
