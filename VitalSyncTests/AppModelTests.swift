import Foundation
import Testing
@testable import VitalSync

@MainActor
struct AppModelTests {
    @Test func restoresConnectedStateFromCredentialStore() async {
        let store = InMemoryCredentialStore(tokens: .synthetic)
        let model = AppModel(authenticator: StubAuthenticator(), credentialStore: store)

        await model.restoreConnectionState()

        #expect(model.connectionState == .connected)
    }

    @Test func completedAuthorizationBecomesConnected() async {
        let store = InMemoryCredentialStore()
        let authenticator = StubAuthenticator {
            await store.save(.synthetic)
        }
        let model = AppModel(authenticator: authenticator, credentialStore: store)

        await model.connectToOura()

        #expect(model.connectionState == .connected)
        #expect(await store.load() == .synthetic)
    }

    @Test func cancelledAuthorizationReturnsToDisconnectedWithoutError() async {
        let model = AppModel(
            authenticator: StubAuthenticator { throw AuthenticationError.userCancelled },
            credentialStore: InMemoryCredentialStore()
        )

        await model.connectToOura()

        #expect(model.connectionState == .disconnected)
        #expect(model.connectionMessage == nil)
    }

    @Test func disconnectDeletesCredentials() async {
        let store = InMemoryCredentialStore(tokens: .synthetic)
        let model = AppModel(authenticator: StubAuthenticator(), credentialStore: store)

        await model.disconnectFromOura()

        #expect(model.connectionState == .disconnected)
        #expect(await store.load() == nil)
    }
}

@MainActor
private final class StubAuthenticator: OAuthAuthorizing {
    private let operation: @MainActor () async throws -> Void

    init(operation: @escaping @MainActor () async throws -> Void = {}) {
        self.operation = operation
    }

    func connect() async throws {
        try await operation()
    }
}

private actor InMemoryCredentialStore: CredentialStore {
    private var tokens: OAuthTokens?

    init(tokens: OAuthTokens? = nil) {
        self.tokens = tokens
    }

    func load() -> OAuthTokens? { tokens }
    func save(_ tokens: OAuthTokens) { self.tokens = tokens }
    func delete() { tokens = nil }
}

private extension OAuthTokens {
    static let synthetic = OAuthTokens(
        accessToken: "synthetic-access",
        refreshToken: "synthetic-refresh",
        expiresAt: Date(timeIntervalSince1970: 4_102_444_800),
        scope: "daily"
    )
}
