import CryptoKit
import Foundation
import WordLoopCore

enum CourseContentValidation {
    private static let stableIDPattern = #"^[a-z0-9]+(?:-[a-z0-9]+)*$"#
    private static let semverPattern = #"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-((?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"#
    private static let timestampPattern = #"^[0-9]{4}-(0[1-9]|1[0-2])-([0-2][0-9]|3[01])T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]Z$"#
    private static let digestPattern = #"^[0-9a-f]{64}$"#

    static func decodeCatalog(_ data: Data, document: String = "catalog.json") throws -> CatalogWire {
        let object = try jsonObject(data, document: document)
        try requireKeys(
            object,
            allowed: ["schemaVersion", "generatedAt", "defaultCourseId", "collections", "courses"],
            document: document
        )
        try requireArrayObjects(object["collections"], document: "\(document).collections") { item, path in
            try requireKeys(item, allowed: ["id", "label", "title", "subtitle"], document: path)
        }
        try requireArrayObjects(object["courses"], document: "\(document).courses") { item, path in
            try requireKeys(
                item,
                allowed: [
                    "id", "collectionId", "title", "subtitle", "description", "kind", "practiceOrder",
                    "contentVersion", "minimumAppVersion", "manifestURL", "manifestSHA256", "downloadSize", "status",
                ],
                document: path
            )
        }
        return try decode(CatalogWire.self, from: data, document: document)
    }

    static func decodeCourse(_ data: Data, document: String) throws -> CourseWire {
        let object = try jsonObject(data, document: document)
        try requireKeys(
            object,
            allowed: [
                "schemaVersion", "id", "collectionId", "contentVersion", "title", "subtitle", "description",
                "kind", "practiceOrder", "entries",
            ],
            document: document
        )
        try requireArrayObjects(object["entries"], document: "\(document).entries") { item, path in
            try requireKeys(
                item,
                allowed: ["id", "text", "translation", "translations", "phonetic", "highlights", "audio", "durationMilliseconds"],
                document: path
            )
        }
        return try decode(CourseWire.self, from: data, document: document)
    }

    static func decodeIntegrity(_ data: Data, document: String) throws -> IntegrityWire {
        let object = try jsonObject(data, document: document)
        try requireKeys(object, allowed: ["schemaVersion", "courseId", "contentVersion", "files"], document: document)
        try requireArrayObjects(object["files"], document: "\(document).files") { item, path in
            try requireKeys(item, allowed: ["path", "bytes", "sha256"], document: path)
        }
        return try decode(IntegrityWire.self, from: data, document: document)
    }

    static func requireSchema(_ schemaVersion: Int, document: String) throws {
        guard schemaVersion == 1 else {
            throw CourseContentError.unsupportedSchema(document: document, found: schemaVersion)
        }
    }

    static func requireStableID(_ value: String, kind: String) throws {
        guard matches(value, pattern: stableIDPattern) else {
            throw CourseContentError.invalidID(kind: kind, value: value)
        }
    }

    static func requireNonEmpty(_ value: String, document: String, field: String) throws {
        guard !value.isEmpty else {
            throw CourseContentError.invalidValue(document: document, field: field)
        }
    }

    static func requirePositive(_ value: Int, document: String, field: String) throws {
        guard value > 0 else {
            throw CourseContentError.invalidValue(document: document, field: field)
        }
    }

    static func requireSemver(_ value: String, document: String) throws {
        guard matches(value, pattern: semverPattern) else {
            throw CourseContentError.invalidValue(document: document, field: "minimumAppVersion")
        }
    }

    static func requireTimestamp(_ value: String, document: String) throws {
        guard matches(value, pattern: timestampPattern),
              ISO8601DateFormatter().date(from: value) != nil else {
            throw CourseContentError.invalidValue(document: document, field: "generatedAt")
        }
    }

    static func requireDigest(_ value: String, document: String, field: String = "sha256") throws {
        guard matches(value, pattern: digestPattern) else {
            throw CourseContentError.invalidValue(document: document, field: field)
        }
    }

    static func requireUnique<T: Hashable>(_ values: [T], kind: String, string: (T) -> String) throws {
        var seen = Set<T>()
        for value in values where !seen.insert(value).inserted {
            throw CourseContentError.duplicateID(kind: kind, value: string(value))
        }
    }

    static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.contains("\\"),
              !path.contains("//"),
              path.range(of: #"%[0-9A-Fa-f]{2}"#, options: .regularExpression) == nil,
              path.range(of: #"^[A-Za-z]:"#, options: .regularExpression) == nil,
              path.range(of: #"^[A-Za-z][A-Za-z0-9+.-]*:"#, options: .regularExpression) == nil else {
            return false
        }
        return path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { $0 != "." && $0 != ".." && !$0.isEmpty }
    }

    static func isSafeAudioPath(_ path: String) -> Bool {
        isSafeRelativePath(path) && path.hasPrefix("audio/") && path.hasSuffix(".m4a") && !path.dropFirst(6).contains(":")
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func matches(_ value: String, pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    private static func jsonObject(_ data: Data, document: String) throws -> [String: Any] {
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CourseContentError.malformedJSON(document)
            }
            return object
        } catch let error as CourseContentError {
            throw error
        } catch {
            throw CourseContentError.malformedJSON(document)
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data, document: String) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw CourseContentError.malformedJSON(document)
        }
    }

    private static func requireKeys(_ object: [String: Any], allowed: Set<String>, document: String) throws {
        if let unknown = Set(object.keys).subtracting(allowed).sorted().first {
            throw CourseContentError.unknownField(document: document, field: unknown)
        }
    }

    private static func requireArrayObjects(
        _ value: Any?,
        document: String,
        validate: ([String: Any], String) throws -> Void
    ) throws {
        guard let values = value as? [Any] else { return }
        for (index, value) in values.enumerated() {
            guard let item = value as? [String: Any] else { continue }
            try validate(item, "\(document)[\(index)]")
        }
    }
}
