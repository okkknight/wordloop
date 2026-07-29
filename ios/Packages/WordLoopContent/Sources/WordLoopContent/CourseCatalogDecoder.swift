import Foundation
import WordLoopCore

enum CourseCatalogDecoder {
    static func decode(_ data: Data, document: String = "catalog.json") throws -> CourseCatalog {
        let wire = try CourseContentValidation.decodeCatalog(data, document: document)
        try CourseContentValidation.requireSchema(wire.schemaVersion, document: document)
        try CourseContentValidation.requireTimestamp(wire.generatedAt, document: document)
        try CourseContentValidation.requireStableID(wire.defaultCourseId, kind: "default course")
        guard !wire.collections.isEmpty else {
            throw CourseContentError.invalidValue(document: document, field: "collections")
        }
        guard !wire.courses.isEmpty else {
            throw CourseContentError.invalidValue(document: document, field: "courses")
        }

        let collections = try wire.collections.map { item -> CourseCollectionDescriptor in
            try CourseContentValidation.requireStableID(item.id, kind: "collection")
            try CourseContentValidation.requireNonEmpty(item.label, document: document, field: "collection.label")
            try CourseContentValidation.requireNonEmpty(item.title, document: document, field: "collection.title")
            try CourseContentValidation.requireNonEmpty(item.subtitle, document: document, field: "collection.subtitle")
            guard let id = CourseCollectionID(rawValue: item.id) else {
                throw CourseContentError.invalidID(kind: "collection", value: item.id)
            }
            return CourseCollectionDescriptor(id: id, label: item.label, title: item.title, subtitle: item.subtitle)
        }
        try CourseContentValidation.requireUnique(collections.map(\.id), kind: "collection") { $0.rawValue }
        let collectionIDs = Set(collections.map(\.id))

        let descriptors = try wire.courses.map { item -> CourseDescriptor in
            try validateDescriptor(item, document: document)
            guard let id = CourseID(rawValue: item.id) else {
                throw CourseContentError.invalidID(kind: "course", value: item.id)
            }
            let expectedManifest = "courses/\(id.rawValue)/\(item.contentVersion)/course.json"
            guard item.manifestURL == expectedManifest else {
                throw CourseContentError.metadataMismatch(courseID: id.rawValue, field: "manifestLocation")
            }
            guard let collection = CourseCollectionID(rawValue: item.collectionId) else {
                throw CourseContentError.invalidID(kind: "collection", value: item.collectionId)
            }
            guard collectionIDs.contains(collection) else {
                throw CourseContentError.unknownCollection(courseID: item.id, collectionID: item.collectionId)
            }
            guard let kind = CourseKind(rawValue: item.kind) else {
                throw CourseContentError.invalidValue(document: document, field: "kind")
            }
            guard let practiceOrder = CoursePracticeOrder(rawValue: item.practiceOrder) else {
                throw CourseContentError.invalidValue(document: document, field: "practiceOrder")
            }
            guard let availability = CourseAvailability(rawValue: item.status) else {
                throw CourseContentError.invalidValue(document: document, field: "status")
            }
            return CourseDescriptor(
                id: id, collectionID: collection, title: item.title, subtitle: item.subtitle,
                description: item.description, kind: kind, practiceOrder: practiceOrder,
                contentVersion: item.contentVersion, minimumAppVersion: item.minimumAppVersion,
                manifestLocation: item.manifestURL, manifestSHA256: item.manifestSHA256,
                downloadSize: item.downloadSize, availability: availability
            )
        }
        try CourseContentValidation.requireUnique(descriptors.map(\.id), kind: "course") { $0.rawValue }
        guard let defaultID = CourseID(rawValue: wire.defaultCourseId), descriptors.contains(where: { $0.id == defaultID }) else {
            throw CourseContentError.defaultCourseMissing(wire.defaultCourseId)
        }
        return CourseCatalog(
            schemaVersion: wire.schemaVersion, generatedAt: wire.generatedAt, defaultCourseID: defaultID,
            collections: collections, courses: descriptors
        )
    }

    private static func validateDescriptor(_ item: DescriptorWire, document: String) throws {
        try CourseContentValidation.requireStableID(item.id, kind: "course")
        try CourseContentValidation.requireStableID(item.collectionId, kind: "collection")
        try CourseContentValidation.requireNonEmpty(item.title, document: document, field: "course.title")
        try CourseContentValidation.requirePositive(item.contentVersion, document: document, field: "contentVersion")
        try CourseContentValidation.requirePositive(item.downloadSize, document: document, field: "downloadSize")
        try CourseContentValidation.requireSemver(item.minimumAppVersion, document: document)
        try CourseContentValidation.requireDigest(item.manifestSHA256, document: document, field: "manifestSHA256")
        guard CourseContentValidation.isSafeRelativePath(item.manifestURL), item.manifestURL.hasSuffix("/course.json") else {
            throw CourseContentError.unsafePath(item.manifestURL)
        }
    }
}
