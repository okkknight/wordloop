import Foundation
import WordLoopCore

public enum CourseInstallationStatus: String, Codable, Equatable, Sendable {
    case downloading
    case installed
    case failed
}

/// Durable metadata for one downloaded course version. The content itself remains under
/// the app's content directory and is validated before this record becomes `installed`.
public struct CourseInstallation: Codable, Equatable, Sendable, Identifiable {
    public var id: String { "\(courseID.rawValue)-\(contentVersion)" }
    public let courseID: CourseID
    public let contentVersion: Int
    public let relativePath: String
    public let downloadedBytes: Int
    public let expectedBytes: Int
    public let status: CourseInstallationStatus
    public let lastVerifiedAt: Date?
    public let catalogETag: String?
    public let backgroundTaskIdentifier: String?

    public init(
        courseID: CourseID,
        contentVersion: Int,
        relativePath: String,
        downloadedBytes: Int,
        expectedBytes: Int,
        status: CourseInstallationStatus,
        lastVerifiedAt: Date? = nil,
        catalogETag: String? = nil,
        backgroundTaskIdentifier: String? = nil
    ) {
        self.courseID = courseID
        self.contentVersion = contentVersion
        self.relativePath = relativePath
        self.downloadedBytes = max(0, downloadedBytes)
        self.expectedBytes = max(0, expectedBytes)
        self.status = status
        self.lastVerifiedAt = lastVerifiedAt
        self.catalogETag = catalogETag
        self.backgroundTaskIdentifier = backgroundTaskIdentifier
    }
}

public enum CourseInstallationStoreError: Error, Equatable, Sendable {
    case unsafePath(String)
}

/// A small atomic JSON index. Course media is deliberately not embedded in persistence.
public actor CourseInstallationStore {
    private let fileURL: URL
    private var cached: [CourseInstallation]?

    public init(fileURL: URL) {
        self.fileURL = fileURL.standardizedFileURL
    }

    public func all() throws -> [CourseInstallation] {
        try load().sorted { $0.id < $1.id }
    }

    public func installation(for courseID: CourseID) throws -> CourseInstallation? {
        try load().filter { $0.courseID == courseID }.max { $0.contentVersion < $1.contentVersion }
    }

    public func save(_ installation: CourseInstallation) throws {
        try validate(installation.relativePath)
        var values = try load()
        values.removeAll { $0.courseID == installation.courseID && $0.contentVersion == installation.contentVersion }
        values.append(installation)
        try persist(values)
    }

    public func remove(courseID: CourseID) throws {
        try persist(try load().filter { $0.courseID != courseID })
    }

    /// Removes records whose installed directory disappeared or escaped the content root.
    @discardableResult
    public func reconcile(contentRootURL: URL) throws -> [CourseInstallation] {
        let root = contentRootURL.standardizedFileURL
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        let values = try load()
        let reconciled = values.filter { installation in
            guard CourseContentValidation.isSafeRelativePath(installation.relativePath) else { return false }
            let location = root.appendingPathComponent(installation.relativePath).standardizedFileURL
            guard location.path.hasPrefix(rootPath) else { return false }
            return installation.status != .installed || (try? location.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        if reconciled != values { try persist(reconciled) }
        return reconciled.sorted { $0.id < $1.id }
    }

    private func load() throws -> [CourseInstallation] {
        if let cached { return cached }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cached = []
            return []
        }
        let values = try JSONDecoder().decode([CourseInstallation].self, from: Data(contentsOf: fileURL))
        cached = values
        return values
    }

    private func persist(_ values: [CourseInstallation]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(values).write(to: fileURL, options: .atomic)
        cached = values
    }

    private func validate(_ path: String) throws {
        guard CourseContentValidation.isSafeRelativePath(path) else {
            throw CourseInstallationStoreError.unsafePath(path)
        }
    }
}
