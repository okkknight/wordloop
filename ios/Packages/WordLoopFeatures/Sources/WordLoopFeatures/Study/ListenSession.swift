import Foundation
import WordLoopAudio
import WordLoopCore

struct SessionBinding: Sendable {
    let generation: ListenSessionGeneration
    let courseID: CourseID?
    let entryID: EntryID?
    let requestID: PlaybackRequestID?

    func matches(_ state: StudyState) -> Bool {
        generation == state.listenGeneration
            && courseID == state.selectedCourseID
            && entryID == state.currentEntryID
            && requestID != nil
    }
}

final class StudyTaskSlot: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Void, Never>?

    func replace(with task: Task<Void, Never>) {
        let previous = lock.withLock { () -> Task<Void, Never>? in
            defer { self.task = task }
            return self.task
        }
        previous?.cancel()
    }

    func cancel() {
        let previous = lock.withLock { () -> Task<Void, Never>? in
            defer { task = nil }
            return task
        }
        previous?.cancel()
    }

    deinit {
        cancel()
    }
}
