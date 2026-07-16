import WordLoopCore

/// Session-only progress storage used while the persistent P5 repository is not available.
///
/// Counts are partitioned by course, study mode, and entry. This repository deliberately
/// performs no persistence or networking; all values disappear with the actor instance.
public actor TemporaryProgressRepository {
    private struct Key: Hashable, Sendable {
        let courseID: CourseID
        let mode: StudyMode
        let entryID: EntryID
    }

    private static let masteryCount = 3

    private var counts: [Key: Int] = [:]

    public init() {}

    /// Returns the non-zero counts for one course and study mode.
    public func snapshot(courseID: CourseID, mode: StudyMode) -> [EntryID: Int] {
        counts.reduce(into: [:]) { result, element in
            guard element.key.courseID == courseID, element.key.mode == mode else {
                return
            }
            result[element.key.entryID] = Self.clamped(element.value)
        }
    }

    /// Records one learning round and returns the resulting count, clamped to `0...3`.
    @discardableResult
    public func record(courseID: CourseID, mode: StudyMode, entryID: EntryID) -> Int {
        let key = Key(courseID: courseID, mode: mode, entryID: entryID)
        let updatedCount = Self.clamped((counts[key] ?? 0) + 1)
        counts[key] = updatedCount
        return updatedCount
    }

    /// Marks an entry mastered and returns the mastery count (`3`).
    @discardableResult
    public func master(courseID: CourseID, mode: StudyMode, entryID: EntryID) -> Int {
        let key = Key(courseID: courseID, mode: mode, entryID: entryID)
        counts[key] = Self.masteryCount
        return Self.masteryCount
    }

    private static func clamped(_ count: Int) -> Int {
        min(max(count, 0), masteryCount)
    }
}
