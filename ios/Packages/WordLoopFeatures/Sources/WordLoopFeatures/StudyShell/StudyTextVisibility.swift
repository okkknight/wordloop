public enum StudyTextVisibility: String, CaseIterable, Equatable, Sendable {
    case full
    case focus
    case hidden

    public func next(for kind: StudyShellItem.Kind) -> StudyTextVisibility {
        switch (kind, self) {
        case (.sentence, .full): .focus
        case (.sentence, .focus): .hidden
        case (.sentence, .hidden): .full
        case (.word, .full), (.word, .focus): .hidden
        case (.word, .hidden): .full
        }
    }

    public var accessibilityValue: String {
        let copy = StudyVisibilityCopy.current
        switch self {
        case .full: return copy.fullValue
        case .focus: return copy.focusValue
        case .hidden: return copy.hiddenValue
        }
    }

    public func nextAccessibilityAction(for kind: StudyShellItem.Kind) -> String {
        let copy = StudyVisibilityCopy.current
        switch next(for: kind) {
        case .full: return copy.showFull
        case .focus: return copy.showFocus
        case .hidden: return copy.hide
        }
    }
}
