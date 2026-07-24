import Foundation
import SwiftData
import WordLoopCore
import WordLoopNetworking

public struct StudySession: Equatable, Sendable {
    public let userID: String
    public let username: String?
    public let recentCourseID: CourseID?
}

public actor StudySessionRepository {
    private let context: ModelContext
    private let api: ProgressAPIClient
    private let uuid: @Sendable () -> UUID
    private let now: @Sendable () -> Date
    private let guestIdentity: GuestIdentityStore
    private let activeIdentityID = "active"

    public init(
        container: ModelContainer,
        api: ProgressAPIClient,
        uuid: @escaping @Sendable () -> UUID = { UUID() },
        now: @escaping @Sendable () -> Date = { Date() },
        guestIdentity: GuestIdentityStore = .init()
    ) {
        context = ModelContext(container)
        context.autosaveEnabled = false
        self.api = api
        self.uuid = uuid
        self.now = now
        self.guestIdentity = guestIdentity
    }

    public func restore() throws -> StudySession? {
        guard let identity = try activeIdentity() else {
            guard let userID = guestIdentity.load() else { return nil }
            let date = now()
            context.insert(StudyIdentity(
                identityID: activeIdentityID, userID: userID, username: nil,
                createdAt: date, updatedAt: date
            ))
            try context.save()
            return try session(try activeIdentity()!)
        }
        if identity.username == nil { guestIdentity.save(identity.userID) }
        return try session(identity)
    }

    public func activate(username: String?) throws -> StudySession {
        let normalized = username?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let validName = normalized.flatMap { $0.isEmpty ? nil : $0 }
        let existing = try activeIdentity()
        let userID: String
        if let validName {
            userID = "name:\(validName)"
        } else if let existing, existing.username == nil {
            userID = existing.userID
        } else {
            userID = guestIdentity.load() ?? uuid().uuidString.lowercased()
        }
        if let existing {
            existing.userID = userID
            existing.username = validName
            existing.updatedAt = now()
        } else {
            let date = now()
            context.insert(StudyIdentity(
                identityID: activeIdentityID, userID: userID, username: validName,
                createdAt: date, updatedAt: date
            ))
        }
        if validName == nil { guestIdentity.save(userID) }
        try context.save()
        return try session(try activeIdentity()!)
    }

    public func saveRecentCourse(userID: String, courseID: CourseID) throws {
        let descriptor = FetchDescriptor<CoursePreference>(predicate: #Predicate { $0.userID == userID })
        if let preference = try context.fetch(descriptor).first {
            preference.recentCourseID = courseID.rawValue
            preference.updatedAt = now()
        } else {
            context.insert(CoursePreference(userID: userID, recentCourseID: courseID.rawValue, updatedAt: now()))
        }
        try context.save()
    }

    public func syncRecentCourse(userID: String, mode: StudyMode) async throws -> CourseID? {
        let overview = try await api.fetchProgressOverview(userID: userID, mode: wireMode(mode))
        guard let raw = overview.recentCourseId, let courseID = CourseID(rawValue: raw) else { return nil }
        try saveRecentCourse(userID: userID, courseID: courseID)
        return courseID
    }

    public func publishRecentCourse(userID: String, mode: StudyMode, courseID: CourseID) async throws {
        try saveRecentCourse(userID: userID, courseID: courseID)
        _ = try await api.selectCourse(.init(userId: userID, mode: wireMode(mode), courseId: courseID.rawValue))
    }

    /// Deletes the anonymous profile's synced progress, clears its device
    /// cache, and immediately gives this device a fresh guest identity.
    /// A named legacy profile intentionally cannot use this path because the
    /// app no longer creates named accounts and an email-assisted request is
    /// safer for an identifier a user may have shared elsewhere.
    public func deleteAnonymousData() async throws -> StudySession {
        guard let identity = try activeIdentity(), identity.username == nil,
              UUID(uuidString: identity.userID) != nil else {
            throw StudySessionDeletionError.notAnonymous
        }

        let previousUserID = identity.userID
        _ = try await api.deleteUserData(.init(userId: previousUserID))
        try deleteLocalData(userID: previousUserID)
        guestIdentity.clear()

        let nextUserID = uuid().uuidString.lowercased()
        identity.userID = nextUserID
        identity.updatedAt = now()
        guestIdentity.save(nextUserID)
        try context.save()
        return try session(identity)
    }

    private func activeIdentity() throws -> StudyIdentity? {
        let id = activeIdentityID
        return try context.fetch(FetchDescriptor<StudyIdentity>(predicate: #Predicate { $0.identityID == id })).first
    }

    private func deleteLocalData(userID: String) throws {
        try context.fetch(FetchDescriptor<ProgressRecord>(predicate: #Predicate { $0.userID == userID })).forEach(context.delete)
        try context.fetch(FetchDescriptor<ProgressEvent>(predicate: #Predicate { $0.userID == userID })).forEach(context.delete)
        try context.fetch(FetchDescriptor<CourseCompletionRecord>(predicate: #Predicate { $0.userID == userID })).forEach(context.delete)
        try context.fetch(FetchDescriptor<CourseCompletionEvent>(predicate: #Predicate { $0.userID == userID })).forEach(context.delete)
        try context.fetch(FetchDescriptor<CoursePreference>(predicate: #Predicate { $0.userID == userID })).forEach(context.delete)
        // Resume keys encode every component into one stable key, so remove
        // all WordLoop resume positions alongside a full guest-data wipe.
        // There is only one active profile on a device.
        let prefix = "wordloop.resume."
        UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .forEach(UserDefaults.standard.removeObject(forKey:))
    }

    private func session(_ identity: StudyIdentity) throws -> StudySession {
        let userID = identity.userID
        let preference = try context.fetch(
            FetchDescriptor<CoursePreference>(predicate: #Predicate { $0.userID == userID })
        ).first
        return StudySession(
            userID: userID,
            username: identity.username,
            recentCourseID: preference.flatMap { CourseID(rawValue: $0.recentCourseID) }
        )
    }

    private func wireMode(_ mode: StudyMode) -> ProgressStudyModeDTO {
        mode == .listen ? .listen : .repeat
    }
}

public enum StudySessionDeletionError: Error, Equatable, Sendable {
    case notAnonymous
}
