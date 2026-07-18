import Foundation
import SwiftData
import WordLoopCore
import WordLoopNetworking

public enum ProgressFlushTrigger: String, CaseIterable, Sendable {
    case networkRecovered
    case appBecameActive
    case manualRetry
}

public enum ProgressFlushResult: Equatable, Sendable {
    case completed(sent: Int)
    case coalesced
}

public enum PersistentProgressError: Error, Equatable, Sendable {
    case duplicateEventID(String)
    case invalidStoredMode(String)
    case invalidStoredEntryID(String)
    case invalidEventKind(String)
    case invalidOutboxState(String)
}

public actor PersistentProgressRepository {
    private let context: ModelContext
    private let api: ProgressAPIClient
    private let eventID: @Sendable () -> String
    private let now: @Sendable () -> Date
    private var activePartitions: Set<String> = []

    public init(
        container: ModelContainer,
        api: ProgressAPIClient,
        eventID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.context = ModelContext(container)
        self.context.autosaveEnabled = false
        self.api = api
        self.eventID = eventID
        self.now = now
    }

    @discardableResult
    public func record(userID: String, mode: StudyMode, courseID: CourseID, entryID: EntryID) throws -> Int {
        try enqueue(
            userID: userID, mode: mode, courseID: courseID, entryID: entryID,
            kind: .increment
        )
    }

    @discardableResult
    public func master(userID: String, mode: StudyMode, courseID: CourseID, entryID: EntryID) throws -> Int {
        try enqueue(
            userID: userID, mode: mode, courseID: courseID, entryID: entryID,
            kind: .master
        )
    }

    public func snapshot(userID: String, mode: StudyMode, courseID: CourseID) throws -> [EntryID: Int] {
        try recoverInterruptedEvents(userID: userID, mode: mode)
        return try projectedSnapshot(userID: userID, mode: mode, courseID: courseID)
    }

    @discardableResult
    public func flush(
        userID: String,
        mode: StudyMode,
        trigger _: ProgressFlushTrigger
    ) async throws -> ProgressFlushResult {
        let partition = partitionKey(userID: userID, mode: mode)
        guard activePartitions.insert(partition).inserted else { return .coalesced }
        defer { activePartitions.remove(partition) }

        try recoverInterruptedEvents(userID: userID, mode: mode)
        let events = try pendingEvents(userID: userID, mode: mode)
        var sent = 0
        for event in events {
            let kind = try eventKind(event.kindRawValue)
            event.stateRawValue = ProgressOutboxState.sending.rawValue
            event.attemptCount += 1
            event.lastAttemptAt = now()
            try context.save()

            do {
                let response = try await api.sendCourseProgress(.init(
                    userId: event.userID,
                    mode: wireMode(mode),
                    clientEventId: event.clientEventID,
                    courseId: event.courseID,
                    itemId: event.entryID,
                    markMastered: kind == .master
                ))
                try applyConfirmed(
                    userID: event.userID,
                    mode: mode,
                    courseID: event.courseID,
                    entryID: response.itemId,
                    count: response.studyCount,
                    updatedAt: now()
                )
                context.delete(event)
                try context.save()
                sent += 1
            } catch {
                event.stateRawValue = ProgressOutboxState.pending.rawValue
                try? context.save()
                throw error
            }
        }
        return .completed(sent: sent)
    }

    public func refresh(userID: String, mode: StudyMode, courseID: CourseID) async throws -> [EntryID: Int] {
        let response = try await api.fetchCourseProgress(.init(
            userID: userID,
            mode: wireMode(mode),
            courseID: courseID.rawValue
        ))
        let existing = try confirmedRecords(userID: userID, mode: mode, courseID: courseID.rawValue)
        existing.forEach(context.delete)
        for row in response.progress {
            try applyConfirmed(
                userID: userID,
                mode: mode,
                courseID: courseID.rawValue,
                entryID: row.itemId,
                count: row.studyCount,
                updatedAt: now()
            )
        }
        try context.save()
        return try projectedSnapshot(userID: userID, mode: mode, courseID: courseID)
    }

    private func enqueue(
        userID: String,
        mode: StudyMode,
        courseID: CourseID,
        entryID: EntryID,
        kind: ProgressEventKind
    ) throws -> Int {
        let id = eventID()
        let descriptor = FetchDescriptor<ProgressEvent>(predicate: #Predicate { $0.clientEventID == id })
        guard try context.fetchCount(descriptor) == 0 else {
            throw PersistentProgressError.duplicateEventID(id)
        }
        context.insert(ProgressEvent(
            clientEventID: id,
            userID: userID,
            modeRawValue: mode.rawValue,
            courseID: courseID.rawValue,
            entryID: entryID.rawValue,
            kindRawValue: kind.rawValue,
            stateRawValue: ProgressOutboxState.pending.rawValue,
            createdAt: now()
        ))
        try context.save()
        return try projectedCount(
            userID: userID, mode: mode, courseID: courseID.rawValue, entryID: entryID.rawValue
        )
    }

    private func projectedSnapshot(userID: String, mode: StudyMode, courseID: CourseID) throws -> [EntryID: Int] {
        var raw: [String: Int] = Dictionary(uniqueKeysWithValues: try confirmedRecords(
            userID: userID, mode: mode, courseID: courseID.rawValue
        ).map { ($0.entryID, clamped($0.studyCount)) })
        for event in try events(userID: userID, mode: mode, courseID: courseID.rawValue) {
            let state = try outboxState(event.stateRawValue)
            guard state != .acknowledged else { continue }
            switch try eventKind(event.kindRawValue) {
            case .increment:
                raw[event.entryID] = clamped(raw[event.entryID, default: 0] + 1)
            case .master:
                raw[event.entryID] = 3
            }
        }
        return try raw.reduce(into: [:]) { result, item in
            guard let id = EntryID(rawValue: item.key) else {
                throw PersistentProgressError.invalidStoredEntryID(item.key)
            }
            if item.value > 0 { result[id] = item.value }
        }
    }

    private func projectedCount(userID: String, mode: StudyMode, courseID: String, entryID: String) throws -> Int {
        guard let course = CourseID(rawValue: courseID), let entry = EntryID(rawValue: entryID) else {
            throw PersistentProgressError.invalidStoredEntryID(entryID)
        }
        return try projectedSnapshot(userID: userID, mode: mode, courseID: course)[entry, default: 0]
    }

    private func confirmedRecords(userID: String, mode: StudyMode, courseID: String) throws -> [ProgressRecord] {
        let rawMode = mode.rawValue
        return try context.fetch(FetchDescriptor<ProgressRecord>(predicate: #Predicate {
            $0.userID == userID && $0.modeRawValue == rawMode && $0.courseID == courseID
        }))
    }

    private func events(userID: String, mode: StudyMode, courseID: String) throws -> [ProgressEvent] {
        let rawMode = mode.rawValue
        return try context.fetch(FetchDescriptor<ProgressEvent>(
            predicate: #Predicate {
                $0.userID == userID && $0.modeRawValue == rawMode && $0.courseID == courseID
            },
            sortBy: [SortDescriptor(\ProgressEvent.createdAt), SortDescriptor(\ProgressEvent.clientEventID)]
        ))
    }

    private func pendingEvents(userID: String, mode: StudyMode) throws -> [ProgressEvent] {
        let rawMode = mode.rawValue
        let values = try context.fetch(FetchDescriptor<ProgressEvent>(
            predicate: #Predicate { $0.userID == userID && $0.modeRawValue == rawMode },
            sortBy: [SortDescriptor(\ProgressEvent.createdAt), SortDescriptor(\ProgressEvent.clientEventID)]
        ))
        return try values.filter { try outboxState($0.stateRawValue) != .acknowledged }
    }

    private func recoverInterruptedEvents(userID: String, mode: StudyMode) throws {
        let rawMode = mode.rawValue
        let values = try context.fetch(FetchDescriptor<ProgressEvent>(predicate: #Predicate {
            $0.userID == userID && $0.modeRawValue == rawMode
        }))
        var changed = false
        for event in values {
            switch try outboxState(event.stateRawValue) {
            case .sending:
                event.stateRawValue = ProgressOutboxState.pending.rawValue
                changed = true
            case .pending, .acknowledged:
                break
            }
        }
        if changed { try context.save() }
    }

    private func applyConfirmed(
        userID: String,
        mode: StudyMode,
        courseID: String,
        entryID: String,
        count: Int,
        updatedAt: Date
    ) throws {
        let recordID = ProgressRecord.makeID(
            userID: userID, modeRawValue: mode.rawValue, courseID: courseID, entryID: entryID
        )
        let descriptor = FetchDescriptor<ProgressRecord>(predicate: #Predicate { $0.recordID == recordID })
        if let record = try context.fetch(descriptor).first {
            record.studyCount = clamped(count)
            record.updatedAt = updatedAt
        } else {
            context.insert(ProgressRecord(
                userID: userID,
                modeRawValue: mode.rawValue,
                courseID: courseID,
                entryID: entryID,
                studyCount: clamped(count),
                updatedAt: updatedAt
            ))
        }
    }

    private func eventKind(_ rawValue: String) throws -> ProgressEventKind {
        guard let value = ProgressEventKind(rawValue: rawValue) else {
            throw PersistentProgressError.invalidEventKind(rawValue)
        }
        return value
    }

    private func outboxState(_ rawValue: String) throws -> ProgressOutboxState {
        guard let value = ProgressOutboxState(rawValue: rawValue) else {
            throw PersistentProgressError.invalidOutboxState(rawValue)
        }
        return value
    }

    private func wireMode(_ mode: StudyMode) -> ProgressStudyModeDTO {
        switch mode {
        case .listen: .listen
        case .repeat: .repeat
        }
    }

    private func partitionKey(userID: String, mode: StudyMode) -> String {
        ProgressStableKey.make(userID, mode.rawValue)
    }

    private func clamped(_ count: Int) -> Int { min(max(count, 0), 3) }
}
