import WordLoopDesignSystem

public enum StudyRepeatPresentationState: String, Equatable, Sendable {
    case listening

    public var title: String { "LISTENING" }
    public var instruction: String { "先听一遍标准发音" }
}

public struct StudyShellViewState: Equatable, Sendable {
    public var palette: PosterPalette
    public var courseLabel: String
    public var courseTitle: String
    public var currentIndex: Int
    public var totalCount: Int
    public var item: StudyShellItem
    public var mode: StudyShellMode
    public var visibility: StudyTextVisibility
    public var masteryCount: Int {
        didSet { masteryCount = Self.clampMastery(masteryCount) }
    }
    public var isAutoplayEnabled: Bool
    public var isRepeatPaused: Bool
    public var repeatPresentationState: StudyRepeatPresentationState

    public init(
        palette: PosterPalette,
        courseLabel: String,
        courseTitle: String,
        currentIndex: Int,
        totalCount: Int,
        item: StudyShellItem,
        mode: StudyShellMode,
        visibility: StudyTextVisibility,
        masteryCount: Int,
        isAutoplayEnabled: Bool,
        isRepeatPaused: Bool,
        repeatPresentationState: StudyRepeatPresentationState = .listening
    ) {
        self.palette = palette
        self.courseLabel = courseLabel
        self.courseTitle = courseTitle
        self.currentIndex = currentIndex
        self.totalCount = totalCount
        self.item = item
        self.mode = mode
        self.visibility = visibility
        self.masteryCount = Self.clampMastery(masteryCount)
        self.isAutoplayEnabled = isAutoplayEnabled
        self.isRepeatPaused = isRepeatPaused
        self.repeatPresentationState = repeatPresentationState
    }

    public var progressLabel: String { "\(currentIndex)/\(totalCount)" }
    public var isTooEasyDisabled: Bool { masteryCount >= 3 }
    public var isNextDisabled: Bool { false }
    public var isPauseDisabled: Bool { mode != .repeat }
    public var isAutoplayDisabled: Bool { mode != .listen }

    public static let baselineEnglish = "Uh, my dad still isn't completely comfortable with this."

    public static var baselineSentence: StudyShellViewState {
        let highlight = StudyShellItem.highlightRanges(
            matching: "completely comfortable",
            in: baselineEnglish
        )
        return .init(
            palette: palette(id: "sun"),
            courseLabel: "MODERN FAMILY · S01E01",
            courseTitle: "MODERN FAMILY",
            currentIndex: 75,
            totalCount: 91,
            item: .init(
                id: "modern-family-s01e01-75",
                kind: .sentence,
                english: baselineEnglish,
                translation: "我爸对这事还是不太习惯",
                highlightRanges: highlight
            ),
            mode: .repeat,
            visibility: .full,
            masteryCount: 1,
            isAutoplayEnabled: false,
            isRepeatPaused: false
        )
    }

    public static var word: StudyShellViewState {
        var state = baselineSentence
        state.item = .init(
            id: "word-comfortable",
            kind: .word,
            english: "comfortable",
            phonetic: "/ˈkʌmftəbl/",
            translation: "舒服的；自在的"
        )
        return state
    }

    public static var longWord: StudyShellViewState {
        var state = word
        state.item = .init(
            id: "word-misunderstanding",
            kind: .word,
            english: "misunderstanding",
            phonetic: "/ˌmɪsʌndərˈstændɪŋ/",
            translation: "误会；误解"
        )
        return state
    }

    public static func fixture(arguments: [String]) -> StudyShellViewState {
        let itemName = value(after: "-wordloop-study-item", in: arguments)
        var state: StudyShellViewState = switch itemName {
        case "word": .word
        case "long-word": .longWord
        default: .baselineSentence
        }

        if let raw = value(after: "-wordloop-study-mode", in: arguments),
           let mode = StudyShellMode(rawValue: raw) {
            state.mode = mode
        }
        if let raw = value(after: "-wordloop-study-visibility", in: arguments),
           let visibility = StudyTextVisibility(rawValue: raw) {
            state.visibility = visibility
        }
        if let id = value(after: "-wordloop-study-palette", in: arguments) {
            state.palette = palette(id: id)
        }
        if let raw = value(after: "-wordloop-study-mastery", in: arguments),
           let count = Int(raw) {
            state.masteryCount = count
        }
        if let raw = value(after: "-wordloop-study-autoplay", in: arguments) {
            state.isAutoplayEnabled = parseBoolean(raw)
        }

        if arguments.contains("-wordloop-study-listen") { state.mode = .listen }
        if arguments.contains("-wordloop-study-repeat") { state.mode = .repeat }
        if arguments.contains("-wordloop-study-word") { state = applyingItem(.word, to: state) }
        if arguments.contains("-wordloop-study-long-word") { state = applyingItem(.longWord, to: state) }
        if arguments.contains("-wordloop-study-focus") { state.visibility = .focus }
        if arguments.contains("-wordloop-study-hidden") { state.visibility = .hidden }
        if arguments.contains("-wordloop-study-autoplay-on") { state.isAutoplayEnabled = true }
        if state.item.kind == .word, state.visibility == .focus { state.visibility = .full }
        return state
    }

    private static func applyingItem(_ fixture: StudyShellViewState, to state: StudyShellViewState) -> StudyShellViewState {
        var result = state
        result.item = fixture.item
        if result.item.kind == .word, result.visibility == .focus { result.visibility = .full }
        return result
    }

    private static func value(after key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1].lowercased()
    }

    private static func parseBoolean(_ raw: String) -> Bool {
        ["1", "true", "yes", "on"].contains(raw.lowercased())
    }

    private static func palette(id: String) -> PosterPalette {
        PosterPalette.all.first(where: { $0.id == id })
            ?? PosterPalette.all.first(where: { $0.id == "sun" })!
    }

    private static func clampMastery(_ value: Int) -> Int {
        min(max(value, 0), 3)
    }
}
