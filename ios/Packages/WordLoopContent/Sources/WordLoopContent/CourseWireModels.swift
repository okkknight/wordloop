import Foundation

struct CatalogWire: Decodable {
    let schemaVersion: Int
    let generatedAt: String
    let defaultCourseId: String
    let collections: [CollectionWire]
    let courses: [DescriptorWire]
}

struct CollectionWire: Decodable {
    let id: String
    let label: String
    let title: String
    let subtitle: String
}

struct DescriptorWire: Decodable {
    let id: String
    let collectionId: String
    let title: String
    let subtitle: String
    let description: String
    let kind: String
    let practiceOrder: String
    let contentVersion: Int
    let minimumAppVersion: String
    let manifestURL: String
    let manifestSHA256: String
    let downloadSize: Int
    let status: String
}

struct CourseWire: Decodable {
    let schemaVersion: Int
    let id: String
    let collectionId: String
    let contentVersion: Int
    let title: String
    let subtitle: String
    let description: String
    let kind: String
    let practiceOrder: String
    let entries: [EntryWire]
}

struct EntryWire: Decodable {
    let id: String
    let text: String
    let translation: String?
    let phonetic: String?
    let highlights: [String]?
    let audio: String
    let durationMilliseconds: Int
}

struct IntegrityWire: Decodable {
    let schemaVersion: Int
    let courseId: String
    let contentVersion: Int
    let files: [IntegrityFileWire]
}

struct IntegrityFileWire: Decodable {
    let path: String
    let bytes: Int
    let sha256: String
}
