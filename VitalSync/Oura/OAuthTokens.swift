import Foundation

struct OAuthTokens: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let scope: String?

    var isExpiringSoon: Bool {
        expiresAt.timeIntervalSinceNow < 60
    }
}

protocol CredentialStore: Sendable {
    func load() async throws -> OAuthTokens?
    func save(_ tokens: OAuthTokens) async throws
    func delete() async throws
}

protocol TokenBroker: Sendable {
    func exchange(code: String, redirectURI: URL) async throws -> OAuthTokens
    func refresh(refreshToken: String) async throws -> OAuthTokens
}

actor TokenManager {
    private let store: any CredentialStore
    private let broker: any TokenBroker
    private var refreshTask: Task<OAuthTokens, Error>?

    init(store: any CredentialStore, broker: any TokenBroker) {
        self.store = store
        self.broker = broker
    }

    func validAccessToken(forceRefresh: Bool = false) async throws -> String {
        guard let current = try await store.load() else {
            throw AuthenticationError.notConnected
        }
        if !forceRefresh && !current.isExpiringSoon {
            return current.accessToken
        }
        return try await refreshedTokens(from: current).accessToken
    }

    private func refreshedTokens(from current: OAuthTokens) async throws -> OAuthTokens {
        if let refreshTask { return try await refreshTask.value }

        let store = self.store
        let broker = self.broker
        let task = Task {
            let rotated = try await broker.refresh(refreshToken: current.refreshToken)
            try await store.save(rotated)
            return rotated
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }
}

enum AuthenticationError: Error, Equatable {
    case notConnected
    case userCancelled
    case invalidCallback
    case stateMismatch
    case brokerRejected
}
