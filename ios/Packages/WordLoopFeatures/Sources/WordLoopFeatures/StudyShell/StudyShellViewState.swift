import Foundation
import WordLoopDesignSystem

public enum StudyRepeatVisualKind: String, CaseIterable, Equatable, Sendable {
    case idleWaveform
    case activeWaveform
    case emphasizedWaveform
    case success
    case failure
}

public enum StudyRepeatPresentationState: String, CaseIterable, Equatable, Sendable {
    case idle
    case connecting
    case ready
    case playing
    case speak
    case speaking
    case scoring
    case passed
    case paused
    case retry
    case error

    public var title: String {
        switch self {
        case .idle: "STANDBY"
        case .connecting: "CONNECTING"
        case .ready: "READY"
        case .playing: "LISTENING"
        case .speak, .speaking: "SPEAKING"
        case .scoring: "CHECKING"
        case .passed: "GREAT"
        case .paused: "PAUSED"
        case .retry, .error: "TRY AGAIN"
        }
    }

    public var instruction: String {
        switch self {
        case .idle: "跟读模式已准备好"
        case .connecting: "正在准备麦克风"
        case .ready: "听完示范后开始跟读"
        case .playing: "先听一遍标准发音"
        case .speak: "请清晰地跟读"
        case .speaking: "正在听你发音"
        case .scoring: "正在分析这次发音"
        case .passed: "这次发音通过了"
        case .paused: "准备好后继续练习"
        case .retry, .error: "请再读一次"
        }
    }

    public var visualKind: StudyRepeatVisualKind {
        switch self {
        case .idle, .ready, .paused: .idleWaveform
        case .connecting, .playing, .speak, .scoring: .activeWaveform
        case .speaking: .emphasizedWaveform
        case .passed: .success
        case .retry, .error: .failure
        }
    }

    public var showsTranscript: Bool {
        self == .retry || self == .error
    }

    public var accessibilityLabel: String {
        "\(title)，\(instruction)"
    }
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
    private var storedRepeatTranscript: String?

    public var repeatTranscript: String? {
        get { repeatPresentationState.showsTranscript ? storedRepeatTranscript : nil }
        set { storedRepeatTranscript = Self.normalizedTranscript(newValue) }
    }

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
        repeatPresentationState: StudyRepeatPresentationState = .playing,
        repeatTranscript: String? = nil
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
        storedRepeatTranscript = Self.normalizedTranscript(repeatTranscript)
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
        let itemName = value(after: "-wordloop-study-item", in: arguments)?.lowercased()
        var state: StudyShellViewState = switch itemName {
        case "word": .word
        case "long-word": .longWord
        default: .baselineSentence
        }

        if let raw = value(after: "-wordloop-study-mode", in: arguments),
           let mode = StudyShellMode(rawValue: raw.lowercased()) {
            state.mode = mode
        }
        if let raw = value(after: "-wordloop-study-visibility", in: arguments),
           let visibility = StudyTextVisibility(rawValue: raw.lowercased()) {
            state.visibility = visibility
        }
        if let id = value(after: "-wordloop-study-palette", in: arguments) {
            state.palette = palette(id: id.lowercased())
        }
        if let raw = value(after: "-wordloop-study-mastery", in: arguments),
           let count = Int(raw) {
            state.masteryCount = count
        }
        if let raw = value(after: "-wordloop-study-autoplay", in: arguments) {
            state.isAutoplayEnabled = parseBoolean(raw)
        }
        if let raw = value(after: "-wordloop-repeat-state", in: arguments)?.lowercased() {
            state.repeatPresentationState = StudyRepeatPresentationState(rawValue: raw) ?? .playing
        }
        if let transcript = value(after: "-wordloop-repeat-transcript", in: arguments) {
            state.repeatTranscript = transcript
        }

        if arguments.contains("-wordloop-study-listen") { state.mode = .listen }
        if arguments.contains("-wordloop-study-repeat") { state.mode = .repeat }
        if arguments.contains("-wordloop-study-word") { state = applyingItem(.word, to: state) }
        if arguments.contains("-wordloop-study-long-word") { state = applyingItem(.longWord, to: state) }
        if arguments.contains("-wordloop-study-focus") { state.visibility = .focus }
        if arguments.contains("-wordloop-study-hidden") { state.visibility = .hidden }
        if arguments.contains("-wordloop-study-autoplay-on") { state.isAutoplayEnabled = true }
        if state.item.kind == .word, state.visibility == .focus { state.visibility = .full }
        state.isRepeatPaused = state.repeatPresentationState == .paused
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
        return arguments[index + 1]
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

    private static func normalizedTranscript(_ transcript: String?) -> String? {
        guard let transcript else { return nil }
        let normalized = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}
