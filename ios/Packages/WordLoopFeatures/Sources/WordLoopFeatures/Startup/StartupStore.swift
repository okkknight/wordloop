import Observation

@MainActor
@Observable
public final class StartupStore {
    public var username: String {
        didSet {
            let constrained = StartupUsernameValidator.constrainedInput(username)
            if username != constrained {
                username = constrained
            }
            validationMessage = nil
        }
    }

    public private(set) var state: StartupState
    public private(set) var validationMessage: String?
    public private(set) var lastSubmission: StartupSubmission?

    public init(
        username: String = "",
        state: StartupState = .idle,
        validationMessage: String? = nil
    ) {
        self.username = StartupUsernameValidator.constrainedInput(username)
        self.state = state
        self.validationMessage = validationMessage
        lastSubmission = nil
    }

    public func updateUsername(_ username: String) {
        self.username = StartupUsernameValidator.constrainedInput(username)
        validationMessage = nil
    }

    @discardableResult
    public func submit() -> StartupSubmission? {
        guard !state.isBusy else {
            return nil
        }

        switch StartupUsernameValidator.validate(username) {
        case let .valid(submission):
            validationMessage = nil
            lastSubmission = submission
            return submission
        case let .invalid(message):
            validationMessage = message
            return nil
        }
    }

    public func setFixtureState(_ state: StartupState) {
        self.state = state
    }

    public func setRuntimeState(_ state: StartupState) {
        self.state = state
    }
}
