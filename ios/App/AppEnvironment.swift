import Foundation

struct AppEnvironment: Equatable, Sendable {
    let apiBaseURL: URL
    let catalogURL: URL
    let configurationName: String

    init(bundle: Bundle = .main) throws {
        try self.init(infoDictionary: bundle.infoDictionary ?? [:])
    }

    init(infoDictionary: [String: Any]) throws {
        apiBaseURL = try Self.url(named: "WordLoopAPIBaseURL", in: infoDictionary)
        catalogURL = try Self.url(named: "WordLoopCatalogURL", in: infoDictionary)
        configurationName = try Self.nonemptyString(
            named: "WordLoopConfigurationName",
            in: infoDictionary
        )
    }

    init(apiBaseURL: URL, catalogURL: URL, configurationName: String) {
        self.apiBaseURL = apiBaseURL
        self.catalogURL = catalogURL
        self.configurationName = configurationName
    }

    private static func url(named name: String, in dictionary: [String: Any]) throws -> URL {
        let value = try nonemptyString(named: name, in: dictionary)
        guard let url = URL(string: value), url.scheme == "https", url.host != nil else {
            throw AppEnvironmentError.invalidHTTPSURL(name: name)
        }
        return url
    }

    private static func nonemptyString(
        named name: String,
        in dictionary: [String: Any]
    ) throws -> String {
        guard let rawValue = dictionary[name] as? String else {
            throw AppEnvironmentError.missingValue(name: name)
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("$(") else {
            throw AppEnvironmentError.missingValue(name: name)
        }
        return value
    }
}

enum AppEnvironmentError: Error, Equatable {
    case missingValue(name: String)
    case invalidHTTPSURL(name: String)
}
