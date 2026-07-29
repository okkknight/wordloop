import Foundation

public enum ProgressDrawerDismissReason: String, Equatable, Sendable {
    case header
    case backdrop
    case swipe
}

public enum ProgressDrawerAction: Equatable, Sendable {
    case presented
    case dismissed(ProgressDrawerDismissReason)
    case updatedQuery(String)
}

public struct ProgressDrawerViewState: Equatable, Sendable {
    public var summary: ProgressDrawerSummary
    public var entries: [ProgressDrawerEntry]
    public var query: String
    public var isPresented: Bool
    public var lastDismissReason: ProgressDrawerDismissReason?

    public init(
        summary: ProgressDrawerSummary,
        entries: [ProgressDrawerEntry],
        query: String = "",
        isPresented: Bool = false,
        lastDismissReason: ProgressDrawerDismissReason? = nil
    ) {
        self.summary = summary
        self.entries = entries
        self.query = query
        self.isPresented = isPresented
        self.lastDismissReason = lastDismissReason
    }

    public var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public var searchPlaceholder: String {
        entries.first?.kind == .word ? "搜索单词或中文释义" : "搜索句子或中文翻译"
    }

    public var filteredEntries: [ProgressDrawerEntry] {
        guard !normalizedQuery.isEmpty else { return entries }
        return entries.filter { $0.matches(normalizedQuery) }
    }

    public static var sentenceBaseline: ProgressDrawerViewState {
        ProgressDrawerFixtures.sentenceBaseline
    }

    public static var word: ProgressDrawerViewState {
        ProgressDrawerFixtures.word
    }

    public static var mixed: ProgressDrawerViewState {
        ProgressDrawerFixtures.mixed
    }

    public static var complete: ProgressDrawerViewState {
        ProgressDrawerFixtures.complete
    }

    public static func fixture(arguments: [String]) -> ProgressDrawerViewState {
        var state: ProgressDrawerViewState
        if arguments.contains("-wordloop-progress-complete") {
            state = .complete
        } else if arguments.contains("-wordloop-progress-mixed") {
            state = .mixed
        } else if arguments.contains("-wordloop-progress-word") {
            state = .word
        } else {
            state = .sentenceBaseline
        }

        if let query = value(after: "-wordloop-progress-query", in: arguments) {
            state.query = query
        }
        if arguments.contains("-wordloop-progress-empty") {
            state.query = "no-such-progress-fixture"
        }
        if arguments.contains("-wordloop-progress-drawer") || arguments.contains("-wordloop-progress-presented") {
            state.isPresented = true
        }
        return state
    }

    private static func value(after key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
