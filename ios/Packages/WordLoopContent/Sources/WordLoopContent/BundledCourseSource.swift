import Foundation
import WordLoopCore

public struct BundledCourseSource: CourseSource, Sendable {
    let resourceRootURL: URL
    private let validationMode: CourseValidationMode

    public init(resourceRootURL: URL, validationMode: CourseValidationMode = .lightweight) {
        self.resourceRootURL = resourceRootURL.standardizedFileURL
        self.validationMode = validationMode
    }

    public static func live(validationMode: CourseValidationMode = .lightweight) throws -> Self {
        guard let root = Bundle.module.url(forResource: "WordLoopContent", withExtension: nil) else {
            throw CourseContentError.resourceRootMissing
        }
        return Self(resourceRootURL: root, validationMode: validationMode)
    }

    public func loadCatalog() throws -> CourseCatalog {
        let document = "catalog.json"
        let data = try readData(relativePath: document)
        return try CourseCatalogDecoder.decode(data, document: document)
    }

    public func loadCourse(descriptor: CourseDescriptor) throws -> Course {
        let expectedManifest = "courses/\(descriptor.id.rawValue)/\(descriptor.contentVersion)/course.json"
        guard descriptor.manifestLocation == expectedManifest else {
            throw CourseContentError.metadataMismatch(courseID: descriptor.id.rawValue, field: "manifestLocation")
        }
        let courseDocument = expectedManifest
        let integrityDocument = "courses/\(descriptor.id.rawValue)/\(descriptor.contentVersion)/integrity.json"
        let courseData = try readData(relativePath: courseDocument)
        let integrityData = try readData(relativePath: integrityDocument)
        let wire = try CourseContentValidation.decodeCourse(courseData, document: courseDocument)
        let integrity = try CourseContentValidation.decodeIntegrity(integrityData, document: integrityDocument)

        try CourseContentValidation.requireSchema(wire.schemaVersion, document: courseDocument)
        try CourseContentValidation.requireSchema(integrity.schemaVersion, document: integrityDocument)
        try validateMetadata(wire, integrity: integrity, descriptor: descriptor)

        let actualManifestDigest = CourseContentValidation.sha256(courseData)
        guard actualManifestDigest == descriptor.manifestSHA256 else {
            throw CourseContentError.manifestDigestMismatch(
                expected: descriptor.manifestSHA256,
                actual: actualManifestDigest
            )
        }

        let integrityByPath = try validateIntegrity(integrity, courseID: descriptor.id)
        guard let manifestRecord = integrityByPath["course.json"] else {
            throw CourseContentError.undeclaredAudio("course.json")
        }
        guard manifestRecord.bytes == courseData.count else {
            throw CourseContentError.byteCountMismatch(
                path: "course.json",
                expected: manifestRecord.bytes,
                actual: courseData.count
            )
        }
        guard manifestRecord.sha256 == actualManifestDigest else {
            throw CourseContentError.manifestDigestMismatch(
                expected: manifestRecord.sha256,
                actual: actualManifestDigest
            )
        }

        guard !wire.entries.isEmpty else {
            throw CourseContentError.invalidValue(document: courseDocument, field: "entries")
        }
        try CourseContentValidation.requireUnique(wire.entries.map(\.id), kind: "entry") { $0 }
        let audioPaths = wire.entries.map(\.audio)
        try CourseContentValidation.requireUnique(audioPaths, kind: "audio") { $0 }
        let declaredAudio = Set(integrityByPath.keys.filter { $0 != "course.json" })
        guard Set(audioPaths) == declaredAudio else {
            let first = Set(audioPaths).symmetricDifference(declaredAudio).sorted().first ?? "audio"
            throw CourseContentError.undeclaredAudio(first)
        }

        let courseRoot = try resolvedURL(relativePath: "courses/\(descriptor.id.rawValue)/\(descriptor.contentVersion)")
        try validateExactCourseFiles(root: courseRoot, expected: Set(integrityByPath.keys).union(["integrity.json"]), courseID: descriptor.id)

        let entries = try wire.entries.map { item -> CourseEntry in
            try CourseContentValidation.requireStableID(item.id, kind: "entry")
            try CourseContentValidation.requireNonEmpty(item.text, document: courseDocument, field: "entry.text")
            try CourseContentValidation.requirePositive(item.durationMilliseconds, document: courseDocument, field: "entry.durationMilliseconds")
            if let translation = item.translation {
                try CourseContentValidation.requireNonEmpty(translation, document: courseDocument, field: "entry.translation")
            }
            if let translations = item.translations {
                for (locale, translation) in translations {
                    try CourseContentValidation.requireNonEmpty(locale, document: courseDocument, field: "entry.translations.locale")
                    try CourseContentValidation.requireNonEmpty(translation, document: courseDocument, field: "entry.translations.\(locale)")
                }
            }
            if let phonetic = item.phonetic {
                try CourseContentValidation.requireNonEmpty(phonetic, document: courseDocument, field: "entry.phonetic")
            }
            let highlights = item.highlights ?? []
            try CourseContentValidation.requireUnique(highlights, kind: "highlight") { $0 }
            for highlight in highlights {
                try CourseContentValidation.requireNonEmpty(highlight, document: courseDocument, field: "entry.highlights")
            }
            guard CourseContentValidation.isSafeAudioPath(item.audio), let record = integrityByPath[item.audio] else {
                throw CourseContentError.unsafePath(item.audio)
            }
            let audioURL = try regularFileURL(relativePath: "courses/\(descriptor.id.rawValue)/\(descriptor.contentVersion)/\(item.audio)")
            let size = try fileSize(audioURL, relativePath: item.audio)
            guard size == record.bytes else {
                throw CourseContentError.byteCountMismatch(path: item.audio, expected: record.bytes, actual: size)
            }
            if validationMode == .full {
                let digest = CourseContentValidation.sha256(try Data(contentsOf: audioURL, options: .mappedIfSafe))
                guard digest == record.sha256 else {
                    throw CourseContentError.audioDigestMismatch(path: item.audio, expected: record.sha256, actual: digest)
                }
            }
            return CourseEntry(
                id: try entryID(item.id),
                text: item.text,
                translation: item.translation,
                translations: item.translations ?? [:],
                phonetic: item.phonetic,
                highlights: highlights,
                audioURL: audioURL,
                durationMilliseconds: item.durationMilliseconds
            )
        }
        return Course(descriptor: descriptor, entries: entries)
    }

    private func validateDescriptor(_ item: DescriptorWire, document: String) throws {
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

    private func validateMetadata(_ wire: CourseWire, integrity: IntegrityWire, descriptor: CourseDescriptor) throws {
        let document = descriptor.manifestLocation
        try CourseContentValidation.requireStableID(wire.id, kind: "course")
        try CourseContentValidation.requireStableID(wire.collectionId, kind: "collection")
        try CourseContentValidation.requireStableID(integrity.courseId, kind: "course")
        try CourseContentValidation.requirePositive(wire.contentVersion, document: document, field: "contentVersion")
        try CourseContentValidation.requirePositive(integrity.contentVersion, document: document, field: "integrity.contentVersion")
        try CourseContentValidation.requireNonEmpty(wire.title, document: document, field: "title")
        _ = try courseKind(wire.kind, document: document)
        _ = try practiceOrder(wire.practiceOrder, document: document)
        let checks: [(String, Bool)] = [
            ("id", wire.id == descriptor.id.rawValue && integrity.courseId == descriptor.id.rawValue),
            ("collectionId", wire.collectionId == descriptor.collectionID.rawValue),
            ("contentVersion", wire.contentVersion == descriptor.contentVersion && integrity.contentVersion == descriptor.contentVersion),
            ("title", wire.title == descriptor.title),
            ("subtitle", wire.subtitle == descriptor.subtitle),
            ("description", wire.description == descriptor.description),
            ("kind", wire.kind == descriptor.kind.rawValue),
            ("practiceOrder", wire.practiceOrder == descriptor.practiceOrder.rawValue),
        ]
        if let failed = checks.first(where: { !$0.1 })?.0 {
            throw CourseContentError.metadataMismatch(courseID: descriptor.id.rawValue, field: failed)
        }
    }

    private func validateIntegrity(_ wire: IntegrityWire, courseID: CourseID) throws -> [String: IntegrityFileWire] {
        var result: [String: IntegrityFileWire] = [:]
        for item in wire.files {
            let validPath = item.path == "course.json" || CourseContentValidation.isSafeAudioPath(item.path)
            guard validPath else { throw CourseContentError.unsafePath(item.path) }
            try CourseContentValidation.requirePositive(item.bytes, document: "integrity.json", field: "bytes")
            try CourseContentValidation.requireDigest(item.sha256, document: "integrity.json")
            guard result[item.path] == nil else { throw CourseContentError.duplicateIntegrityPath(item.path) }
            result[item.path] = item
        }
        guard result.count >= 2, result["course.json"] != nil else {
            throw CourseContentError.unexpectedFiles(courseID: courseID.rawValue)
        }
        return result
    }

    private func validateExactCourseFiles(root: URL, expected: Set<String>, courseID: CourseID) throws {
        let canonicalRoot = root.resolvingSymlinksInPath()
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(at: canonicalRoot, includingPropertiesForKeys: Array(keys)) else {
            throw CourseContentError.missingResource("courses/\(courseID.rawValue)")
        }
        var actual = Set<String>()
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: keys)
            let unresolvedRelative = url.lastPathComponent
            if values.isSymbolicLink == true { throw CourseContentError.symbolicLink(unresolvedRelative) }
            let filePath = url.resolvingSymlinksInPath().path
            let prefix = canonicalRoot.path + "/"
            guard filePath.hasPrefix(prefix) else {
                throw CourseContentError.escapedRoot(courseID.rawValue)
            }
            let relative = String(filePath.dropFirst(prefix.count))
            if values.isRegularFile == true {
                actual.insert(relative)
            } else if values.isDirectory != true {
                throw CourseContentError.nonRegularFile(relative)
            }
        }
        guard actual == expected else { throw CourseContentError.unexpectedFiles(courseID: courseID.rawValue) }
    }

    private func readData(relativePath: String) throws -> Data {
        let url = try regularFileURL(relativePath: relativePath)
        do { return try Data(contentsOf: url, options: .mappedIfSafe) }
        catch { throw CourseContentError.missingResource(relativePath) }
    }

    private func resolvedURL(relativePath: String) throws -> URL {
        guard CourseContentValidation.isSafeRelativePath(relativePath) else { throw CourseContentError.unsafePath(relativePath) }
        let url = resourceRootURL.appendingPathComponent(relativePath).standardizedFileURL
        let rootPath = resourceRootURL.path.hasSuffix("/") ? resourceRootURL.path : resourceRootURL.path + "/"
        guard url.path.hasPrefix(rootPath) else { throw CourseContentError.escapedRoot(relativePath) }
        return url
    }

    private func regularFileURL(relativePath: String) throws -> URL {
        let url = try resolvedURL(relativePath: relativePath)
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { throw CourseContentError.symbolicLink(relativePath) }
            guard values.isRegularFile == true else { throw CourseContentError.nonRegularFile(relativePath) }
            return url
        } catch let error as CourseContentError {
            throw error
        } catch {
            throw CourseContentError.missingResource(relativePath)
        }
    }

    private func fileSize(_ url: URL, relativePath: String) throws -> Int {
        do {
            guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                throw CourseContentError.nonRegularFile(relativePath)
            }
            return size
        } catch let error as CourseContentError {
            throw error
        } catch {
            throw CourseContentError.missingResource(relativePath)
        }
    }

    private func courseID(_ raw: String) throws -> CourseID {
        guard let value = CourseID(rawValue: raw) else { throw CourseContentError.invalidID(kind: "course", value: raw) }
        return value
    }

    private func collectionID(_ raw: String) throws -> CourseCollectionID {
        guard let value = CourseCollectionID(rawValue: raw) else { throw CourseContentError.invalidID(kind: "collection", value: raw) }
        return value
    }

    private func entryID(_ raw: String) throws -> EntryID {
        guard let value = EntryID(rawValue: raw) else { throw CourseContentError.invalidID(kind: "entry", value: raw) }
        return value
    }

    private func courseKind(_ raw: String, document: String) throws -> CourseKind {
        guard let value = CourseKind(rawValue: raw) else { throw CourseContentError.invalidValue(document: document, field: "kind") }
        return value
    }

    private func practiceOrder(_ raw: String, document: String) throws -> CoursePracticeOrder {
        guard let value = CoursePracticeOrder(rawValue: raw) else { throw CourseContentError.invalidValue(document: document, field: "practiceOrder") }
        return value
    }

    private func availability(_ raw: String, document: String) throws -> CourseAvailability {
        guard let value = CourseAvailability(rawValue: raw) else { throw CourseContentError.invalidValue(document: document, field: "status") }
        return value
    }
}
