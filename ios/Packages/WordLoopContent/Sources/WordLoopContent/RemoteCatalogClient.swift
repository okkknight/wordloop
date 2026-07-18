import Foundation
import WordLoopCore

public struct CatalogHTTPTransport: @unchecked Sendable {
    public var data: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    public init(data: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) {
        self.data = data
    }

    public static let live = Self { request in
        try await URLSession.shared.data(for: request)
    }
}

public enum RemoteCatalogError: Error, Equatable, Sendable {
    case invalidURL
    case nonHTTPResponse
    case rejected(statusCode: Int)
    case notModifiedWithoutSnapshot
}

public struct RemoteCatalogSnapshot: Codable, Equatable, Sendable {
    public let catalogData: Data
    public let eTag: String?

    public init(catalogData: Data, eTag: String?) {
        self.catalogData = catalogData
        self.eTag = eTag
    }
}

public protocol RemoteCatalogSnapshotStore: Sendable {
    func load() throws -> RemoteCatalogSnapshot?
    func save(_ snapshot: RemoteCatalogSnapshot) throws
}

/// File-backed cache used by the app so a catalog remains available while offline.
public struct FileRemoteCatalogSnapshotStore: RemoteCatalogSnapshotStore, Sendable {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL.standardizedFileURL
    }

    public func load() throws -> RemoteCatalogSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode(RemoteCatalogSnapshot.self, from: Data(contentsOf: fileURL))
    }

    public func save(_ snapshot: RemoteCatalogSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
    }
}

/// Fetches the versioned catalog, retaining a validated local snapshot for offline startup.
public struct RemoteCatalogClient: Sendable {
    private let url: URL
    private let transport: CatalogHTTPTransport
    private let snapshots: any RemoteCatalogSnapshotStore

    public init(
        url: URL,
        snapshots: any RemoteCatalogSnapshotStore,
        transport: CatalogHTTPTransport = .live
    ) throws {
        guard url.scheme?.lowercased() == "https", url.host != nil else {
            throw RemoteCatalogError.invalidURL
        }
        self.url = url
        self.snapshots = snapshots
        self.transport = transport
    }

    public func cachedCatalog() -> CourseCatalog? {
        guard let snapshot = try? snapshots.load() else { return nil }
        return try? CourseCatalogDecoder.decode(snapshot.catalogData)
    }

    @discardableResult
    public func refresh() async throws -> CourseCatalog {
        let existing = try snapshots.load()
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let eTag = existing?.eTag, !eTag.isEmpty {
            request.setValue(eTag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, rawResponse) = try await transport.data(request)
        guard let response = rawResponse as? HTTPURLResponse else {
            throw RemoteCatalogError.nonHTTPResponse
        }
        if response.statusCode == 304 {
            guard let existing else { throw RemoteCatalogError.notModifiedWithoutSnapshot }
            return try CourseCatalogDecoder.decode(existing.catalogData)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw RemoteCatalogError.rejected(statusCode: response.statusCode)
        }

        let catalog = try CourseCatalogDecoder.decode(data)
        try snapshots.save(.init(catalogData: data, eTag: response.value(forHTTPHeaderField: "ETag")))
        return catalog
    }

    /// Prefer the server catalog when reachable, then its cached snapshot, then built-in content.
    public func catalog(merging bundled: CourseCatalog) async -> CourseCatalog {
        let remote = (try? await refresh()) ?? cachedCatalog()
        guard let remote else { return bundled }
        return Self.merge(remote: remote, bundled: bundled)
    }

    static func merge(remote: CourseCatalog, bundled: CourseCatalog) -> CourseCatalog {
        var collections = Dictionary(uniqueKeysWithValues: bundled.collections.map { ($0.id, $0) })
        for collection in remote.collections { collections[collection.id] = collection }

        var courses = Dictionary(uniqueKeysWithValues: bundled.courses.map { ($0.id, $0) })
        // A remote descriptor is authoritative, including hidden and retired states.
        for course in remote.courses { courses[course.id] = course }

        let allCourses = courses.values.sorted { $0.id.rawValue < $1.id.rawValue }
        let defaultCourseID = allCourses.contains(where: { $0.id == remote.defaultCourseID })
            ? remote.defaultCourseID
            : bundled.defaultCourseID
        return CourseCatalog(
            schemaVersion: remote.schemaVersion,
            generatedAt: remote.generatedAt,
            defaultCourseID: defaultCourseID,
            collections: collections.values.sorted { $0.id.rawValue < $1.id.rawValue },
            courses: allCourses
        )
    }
}
