import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

struct OAuthConfiguration: Sendable {
    let clientID: String
    let authorizationURL: URL
    let redirectURI: URL
    let callbackScheme: String
    let scopes: [String]

    static let placeholder = OAuthConfiguration(
        clientID: "YOUR_OURA_CLIENT_ID",
        authorizationURL: URL(string: "https://cloud.ouraring.com/oauth/authorize")!,
        redirectURI: URL(string: "vitalsync://oauth/oura/callback")!,
        callbackScheme: "vitalsync",
        scopes: ["personal", "daily", "heartrate", "tag", "workout", "session", "spo2", "ring_configuration", "stress", "heart_health"]
    )
}

@MainActor
final class OAuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let configuration: OAuthConfiguration
    private let broker: any TokenBroker
    private let credentialStore: any CredentialStore
    private var session: ASWebAuthenticationSession?

    init(configuration: OAuthConfiguration, broker: any TokenBroker, credentialStore: any CredentialStore) {
        self.configuration = configuration
        self.broker = broker
        self.credentialStore = credentialStore
    }

    func connect() async throws {
        let state = try Self.secureState()
        let authorizationURL = try makeAuthorizationURL(state: state)
        let callbackURL = try await authenticate(at: authorizationURL)
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              components.queryValue(named: "state") == state else {
            throw AuthenticationError.stateMismatch
        }
        guard let code = components.queryValue(named: "code"), !code.isEmpty else {
            throw AuthenticationError.invalidCallback
        }
        let tokens = try await broker.exchange(code: code, redirectURI: configuration.redirectURI)
        try await credentialStore.save(tokens)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    private func authenticate(at url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: configuration.callbackScheme) { callback, error in
                if let error { continuation.resume(throwing: error) }
                else if let callback { continuation.resume(returning: callback) }
                else { continuation.resume(throwing: AuthenticationError.invalidCallback) }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.session = session
            guard session.start() else {
                continuation.resume(throwing: AuthenticationError.invalidCallback)
                return
            }
        }
    }

    private func makeAuthorizationURL(state: String) throws -> URL {
        guard var components = URLComponents(url: configuration.authorizationURL, resolvingAgainstBaseURL: false) else {
            throw AuthenticationError.invalidCallback
        }
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state)
        ]
        guard let url = components.url else { throw AuthenticationError.invalidCallback }
        return url
    }

    private static func secureState() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw AuthenticationError.invalidCallback
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension URLComponents {
    func queryValue(named name: String) -> String? {
        queryItems?.first(where: { $0.name == name })?.value
    }
}
