import Foundation
import WordLoopCore

public struct CourseDownloadTransport: @unchecked Sendable {
    public var data: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    public init(data: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) {
        self.data = data
    }

    public static let live = Self { request in
        try await URLSession.shared.data(for: request)
    }
}

public struct CourseDownloadProgress: Equatable, Sendable {
    public let courseID: CourseID
    public let completedBytes: Int
    public let totalBytes: Int
}

public enum CourseDownloadError: Error, Equatable, Sendable {
    case invalidCatalogURL
    case unsafePath(String)
    case nonHTTPResponse
    case rejected(statusCode: Int)
    case invalidManifest
    case integrityMismatch(path: String)
}

/// Downloads one immutable course version into staging, validates every declared file,
/// then promotes it into the content root. Existing installed versions remain untouched
/// until all validation succeeds.
public actor CourseDownloadManager {
    private let contentRootURL: URL
    private let installations: CourseInstallationStore
    private let transport: CourseDownloadTransport

    public init(
        contentRootURL: URL,
        installations: CourseInstallationStore,
        transport: CourseDownloadTransport = .live
    ) {
        self.contentRootURL = contentRootURL.standardizedFileURL
        self.installations = installations
        self.transport = transport
    }

    @discardableResult
    public func install(
        descriptor: CourseDescriptor,
        catalogURL: URL,
        catalogETag: String? = nil,
        progress: @escaping @Sendable (CourseDownloadProgress) -> Void = { _ in }
    ) async throws -> CourseInstallation {
        guard catalogURL.scheme?.lowercased() == "https", catalogURL.host != nil else {
            throw CourseDownloadError.invalidCatalogURL
        }
        try validateRelativePath(descriptor.manifestLocation)
        let relativePath = "courses/\(descriptor.id.rawValue)/\(descriptor.contentVersion)"
        let pending = CourseInstallation(
            courseID: descriptor.id,
            contentVersion: descriptor.contentVersion,
            relativePath: relativePath,
            downloadedBytes: 0,
            expectedBytes: descriptor.downloadSize,
            status: .downloading,
            catalogETag: catalogETag,
            backgroundTaskIdentifier: UUID().uuidString
        )
        try await installations.save(pending)

        let stage = contentRootURL.appendingPathComponent(".staging/\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
            let manifestData = try await fetch(relativePath: descriptor.manifestLocation, catalogURL: catalogURL)
            guard CourseContentValidation.sha256(manifestData) == descriptor.manifestSHA256 else {
                throw CourseDownloadError.integrityMismatch(path: "course.json")
            }
            let course = try CourseContentValidation.decodeCourse(manifestData, document: descriptor.manifestLocation)
            let integrityPath = "\(relativePath)/integrity.json"
            let integrityData = try await fetch(relativePath: integrityPath, catalogURL: catalogURL)
            let integrity = try CourseContentValidation.decodeIntegrity(integrityData, document: integrityPath)
            try validate(course: course, integrity: integrity, descriptor: descriptor)

            try write(manifestData, relativePath: "course.json", under: stage)
            try write(integrityData, relativePath: "integrity.json", under: stage)
            let records = Dictionary(uniqueKeysWithValues: integrity.files.map { ($0.path, $0) })
            guard let manifestRecord = records["course.json"],
                  manifestRecord.bytes == manifestData.count,
                  manifestRecord.sha256 == descriptor.manifestSHA256 else {
                throw CourseDownloadError.integrityMismatch(path: "course.json")
            }
            let downloadPaths = records.keys.filter { $0 != "course.json" }.sorted()
            var completedBytes = manifestData.count + integrityData.count
            progress(.init(courseID: descriptor.id, completedBytes: completedBytes, totalBytes: descriptor.downloadSize))

            for path in downloadPaths {
                guard let record = records[path] else { continue }
                let data = try await fetch(relativePath: "\(relativePath)/\(path)", catalogURL: catalogURL)
                guard data.count == record.bytes, CourseContentValidation.sha256(data) == record.sha256 else {
                    throw CourseDownloadError.integrityMismatch(path: path)
                }
                try write(data, relativePath: path, under: stage)
                completedBytes += data.count
                progress(.init(courseID: descriptor.id, completedBytes: completedBytes, totalBytes: descriptor.downloadSize))
            }

            let destination = contentRootURL.appendingPathComponent(relativePath, isDirectory: true)
            try promote(stage: stage, to: destination)
            let installed = CourseInstallation(
                courseID: descriptor.id,
                contentVersion: descriptor.contentVersion,
                relativePath: relativePath,
                downloadedBytes: completedBytes,
                expectedBytes: descriptor.downloadSize,
                status: .installed,
                lastVerifiedAt: Date(),
                catalogETag: catalogETag
            )
            try await installations.save(installed)
            return installed
        } catch {
            try? FileManager.default.removeItem(at: stage)
            let failed = CourseInstallation(
                courseID: descriptor.id,
                contentVersion: descriptor.contentVersion,
                relativePath: relativePath,
                downloadedBytes: 0,
                expectedBytes: descriptor.downloadSize,
                status: .failed,
                catalogETag: catalogETag
            )
            try? await installations.save(failed)
            throw error
        }
    }

    private func fetch(relativePath: String, catalogURL: URL) async throws -> Data {
        try validateRelativePath(relativePath)
        let base = catalogURL.deletingLastPathComponent()
        let url = base.appendingPathComponent(relativePath)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, rawResponse) = try await transport.data(request)
        guard let response = rawResponse as? HTTPURLResponse else { throw CourseDownloadError.nonHTTPResponse }
        guard (200..<300).contains(response.statusCode) else { throw CourseDownloadError.rejected(statusCode: response.statusCode) }
        return data
    }

    private func validate(course: CourseWire, integrity: IntegrityWire, descriptor: CourseDescriptor) throws {
        guard course.id == descriptor.id.rawValue,
              course.contentVersion == descriptor.contentVersion,
              integrity.courseId == descriptor.id.rawValue,
              integrity.contentVersion == descriptor.contentVersion else {
            throw CourseDownloadError.invalidManifest
        }
        try CourseContentValidation.requireSchema(course.schemaVersion, document: descriptor.manifestLocation)
        try CourseContentValidation.requireSchema(integrity.schemaVersion, document: "integrity.json")
        let paths = Set(integrity.files.map(\.path))
        guard paths.count == integrity.files.count, paths.contains("course.json") else {
            throw CourseDownloadError.invalidManifest
        }
        let audioPaths = Set(course.entries.map(\.audio))
        guard audioPaths.count == course.entries.count,
              audioPaths.allSatisfy(CourseContentValidation.isSafeAudioPath),
              paths.subtracting(["course.json"]) == audioPaths else {
            throw CourseDownloadError.invalidManifest
        }
        for record in integrity.files {
            guard record.path == "course.json" || CourseContentValidation.isSafeAudioPath(record.path),
                  record.bytes > 0 else {
                throw CourseDownloadError.invalidManifest
            }
            try CourseContentValidation.requireDigest(record.sha256, document: "integrity.json")
        }
    }

    private func write(_ data: Data, relativePath: String, under root: URL) throws {
        try validateRelativePath(relativePath)
        let url = root.appendingPathComponent(relativePath).standardizedFileURL
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard url.path.hasPrefix(rootPath) else { throw CourseDownloadError.unsafePath(relativePath) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private func promote(stage: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let backup = destination.deletingLastPathComponent().appendingPathComponent(".\(destination.lastPathComponent).backup-\(UUID().uuidString)")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.moveItem(at: destination, to: backup)
        }
        do {
            try FileManager.default.moveItem(at: stage, to: destination)
            try? FileManager.default.removeItem(at: backup)
        } catch {
            if FileManager.default.fileExists(atPath: backup.path) {
                try? FileManager.default.moveItem(at: backup, to: destination)
            }
            throw error
        }
    }

    private func validateRelativePath(_ path: String) throws {
        guard CourseContentValidation.isSafeRelativePath(path) else { throw CourseDownloadError.unsafePath(path) }
    }
}
