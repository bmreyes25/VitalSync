import Foundation

enum AppConfigurationError: Error, Equatable {
    case missingValue(String)
    case placeholderValue(String)
    case invalidURL(String)
}

struct AppConfiguration: Sendable, Equatable {
    let ouraClientID: String
    let tokenBrokerBaseURL: URL

    static func load(bundle: Bundle = .main) throws -> AppConfiguration {
        try AppConfiguration(info: bundle.infoDictionary ?? [:])
    }

    init(info: [String: Any]) throws {
        ouraClientID = try Self.requiredString(named: "OuraClientID", in: info)

        let brokerURLString = try Self.requiredString(named: "TokenBrokerBaseURL", in: info)
        guard let brokerURL = URL(string: brokerURLString),
              brokerURL.scheme == "https",
              brokerURL.host != nil else {
            throw AppConfigurationError.invalidURL("TokenBrokerBaseURL")
        }
        tokenBrokerBaseURL = brokerURL
    }

    private static func requiredString(named key: String, in info: [String: Any]) throws -> String {
        guard let value = info[key] as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppConfigurationError.missingValue(key)
        }
        guard !value.contains("YOUR_") else {
            throw AppConfigurationError.placeholderValue(key)
        }
        return value
    }
}
