import Foundation

struct BrokerClient: TokenBroker {
    let baseURL: URL
    let transport: any HTTPTransport

    init(baseURL: URL, transport: any HTTPTransport = URLSessionTransport()) {
        precondition(
            baseURL.scheme == "https" || Self.isLocalDevelopmentURL(baseURL),
            "The token broker must use HTTPS outside local development"
        )
        self.baseURL = baseURL
        self.transport = transport
    }

    func exchange(code: String, redirectURI: URL) async throws -> OAuthTokens {
        try await post(path: "v1/oauth/oura/exchange", body: [
            "code": code,
            "redirect_uri": redirectURI.absoluteString
        ])
    }

    func refresh(refreshToken: String) async throws -> OAuthTokens {
        try await post(path: "v1/oauth/oura/refresh", body: ["refresh_token": refreshToken])
    }

    private func post(path: String, body: [String: String]) async throws -> OAuthTokens {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await transport.data(for: request)
        guard 200..<300 ~= response.statusCode else { throw AuthenticationError.brokerRejected }
        return try JSONDecoder().decode(BrokerResponse.self, from: data).tokens
    }

    private static func isLocalDevelopmentURL(_ url: URL) -> Bool {
        #if DEBUG
        return url.host == "localhost" || url.host == "127.0.0.1"
        #else
        return false
        #endif
    }
}

private struct BrokerResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: TimeInterval
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
    }

    var tokens: OAuthTokens {
        OAuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(expiresIn),
            scope: scope
        )
    }
}
