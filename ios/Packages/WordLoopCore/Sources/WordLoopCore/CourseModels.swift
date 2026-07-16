import Foundation

public enum StudyMode: String, Codable, CaseIterable, Sendable {
    case listen
    case `repeat`
}

public enum CourseKind: String, Codable, CaseIterable, Sendable {
    case word
    case sentence
}

public enum CoursePracticeOrder: String, Codable, CaseIterable, Sendable {
    case random
    case sequential
}

public enum CourseAvailability: String, Codable, CaseIterable, Sendable {
    case available
    case hidden
    case retired
}

public struct CourseCatalog: Codable, Equatable, Hashable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: String
    public let defaultCourseID: CourseID
    public let collections: [CourseCollectionDescriptor]
    public let courses: [CourseDescriptor]

    public init(
        schemaVersion: Int,
        generatedAt: String,
        defaultCourseID: CourseID,
        collections: [CourseCollectionDescriptor],
        courses: [CourseDescriptor]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.defaultCourseID = defaultCourseID
        self.collections = collections
        self.courses = courses
    }
}

public struct CourseCollectionDescriptor: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: CourseCollectionID
    public let label: String
    public let title: String
    public let subtitle: String

    public init(id: CourseCollectionID, label: String, title: String, subtitle: String) {
        self.id = id
        self.label = label
        self.title = title
        self.subtitle = subtitle
    }
}

public struct CourseDescriptor: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: CourseID
    public let collectionID: CourseCollectionID
    public let title: String
    public let subtitle: String
    public let description: String
    public let kind: CourseKind
    public let practiceOrder: CoursePracticeOrder
    public let contentVersion: Int
    public let minimumAppVersion: String
    public let manifestLocation: String
    public let manifestSHA256: String
    public let downloadSize: Int
    public let availability: CourseAvailability

    public init(
        id: CourseID,
        collectionID: CourseCollectionID,
        title: String,
        subtitle: String,
        description: String,
        kind: CourseKind,
        practiceOrder: CoursePracticeOrder,
        contentVersion: Int,
        minimumAppVersion: String,
        manifestLocation: String,
        manifestSHA256: String,
        downloadSize: Int,
        availability: CourseAvailability
    ) {
        self.id = id
        self.collectionID = collectionID
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.kind = kind
        self.practiceOrder = practiceOrder
        self.contentVersion = contentVersion
        self.minimumAppVersion = minimumAppVersion
        self.manifestLocation = manifestLocation
        self.manifestSHA256 = manifestSHA256
        self.downloadSize = downloadSize
        self.availability = availability
    }
}

public struct Course: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: CourseID { descriptor.id }

    public let descriptor: CourseDescriptor
    public let entries: [CourseEntry]

    public init(descriptor: CourseDescriptor, entries: [CourseEntry]) {
        self.descriptor = descriptor
        self.entries = entries
    }
}

public struct CourseEntry: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: EntryID
    public let text: String
    public let translation: String?
    public let phonetic: String?
    public let highlights: [String]
    public let audioURL: URL
    public let durationMilliseconds: Int

    public init(
        id: EntryID,
        text: String,
        translation: String?,
        phonetic: String?,
        highlights: [String],
        audioURL: URL,
        durationMilliseconds: Int
    ) {
        self.id = id
        self.text = text
        self.translation = translation
        self.phonetic = phonetic
        self.highlights = highlights
        self.audioURL = audioURL
        self.durationMilliseconds = durationMilliseconds
    }
}
