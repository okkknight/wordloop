import Observation

public enum StudyShellAction: Equatable, Sendable {
    case selectedMode(StudyShellMode)
    case cycledVisibility(StudyTextVisibility)
    case toggledAutoplay(Bool)
    case toggledPause(Bool)
    case next
    case markedTooEasy
}

@MainActor
@Observable
public final class StudyShellStore {
    public var state: StudyShellViewState
    public private(set) var lastAction: StudyShellAction?

    public init(state: StudyShellViewState = .baselineSentence) {
        self.state = state
    }

    public func selectMode(_ mode: StudyShellMode) {
        state.mode = mode
        lastAction = .selectedMode(mode)
    }

    public func cycleVisibility() {
        state.visibility = state.visibility.next(for: state.item.kind)
        lastAction = .cycledVisibility(state.visibility)
    }

    public func toggleAutoplay() {
        guard !state.isAutoplayDisabled else { return }
        state.isAutoplayEnabled.toggle()
        lastAction = .toggledAutoplay(state.isAutoplayEnabled)
    }

    public func togglePause() {
        guard !state.isPauseDisabled else { return }
        state.isRepeatPaused.toggle()
        lastAction = .toggledPause(state.isRepeatPaused)
    }

    public func next() {
        guard !state.isNextDisabled else { return }
        lastAction = .next
    }

    public func markTooEasy() {
        guard !state.isTooEasyDisabled else { return }
        lastAction = .markedTooEasy
    }
}
