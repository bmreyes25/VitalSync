import Foundation
import Testing
@testable import VitalSync

struct AppConfigurationTests {
    @Test func loadsConfiguredValues() throws {
        let configuration = try AppConfiguration(info: [
            "OuraClientID": "synthetic-client-id",
            "TokenBrokerBaseURL": "https://broker.invalid"
        ])

        #expect(configuration.ouraClientID == "synthetic-client-id")
        #expect(configuration.tokenBrokerBaseURL == URL(string: "https://broker.invalid"))
    }

    @Test func rejectsPlaceholderClientID() {
        #expect(throws: AppConfigurationError.placeholderValue("OuraClientID")) {
            try AppConfiguration(info: [
                "OuraClientID": "YOUR_OURA_CLIENT_ID",
                "TokenBrokerBaseURL": "https://broker.invalid"
            ])
        }
    }

    @Test func requiresSecureBrokerURL() {
        #expect(throws: AppConfigurationError.invalidURL("TokenBrokerBaseURL")) {
            try AppConfiguration(info: [
                "OuraClientID": "synthetic-client-id",
                "TokenBrokerBaseURL": "http://broker.invalid"
            ])
        }
    }

    @Test func rejectsPlaceholderBrokerURL() {
        #expect(throws: AppConfigurationError.placeholderValue("TokenBrokerBaseURL")) {
            try AppConfiguration(info: [
                "OuraClientID": "synthetic-client-id",
                "TokenBrokerBaseURL": "https://YOUR_BROKER.workers.dev"
            ])
        }
    }
}
