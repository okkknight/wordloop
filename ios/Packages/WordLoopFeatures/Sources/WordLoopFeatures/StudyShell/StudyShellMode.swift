public enum StudyShellMode: String, CaseIterable, Equatable, Sendable {
    case listen
    case `repeat`

    public var title: String { rawValue.uppercased() }
}
