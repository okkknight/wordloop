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
        switch self {
        case .full: "全文可见"
        case .focus: "仅重点表达可见"
        case .hidden: "学习内容已隐藏"
        }
    }

    public func nextAccessibilityAction(for kind: StudyShellItem.Kind) -> String {
        switch next(for: kind) {
        case .full: "显示全文"
        case .focus: "只显示重点表达"
        case .hidden: "隐藏学习内容"
        }
    }
}
