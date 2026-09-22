import XCTest
@testable import VitalSync

final class TokenManagerTests: XCTestCase {
    func testConcurrentRefreshIsSingleFlightAndPersistsRotatedToken() async throws {
        let expired = OAuthTokens(accessToken: "expired-synthetic", refreshToken: "old-synthetic", expiresAt: .distantPast, scope: nil)
        let rotated = OAuthTokens(accessToken: "new-synthetic", refreshToken: "rotated-synthetic", expiresAt: .distantFuture, scope: nil)
        let store = MemoryCredentialStore(tokens: expired)
        let broker = CountingBroker(result: rotated)
        let manager = TokenManager(store: store, broker: broker)

        async let first = manager.validAccessToken()
        async let second = manager.validAccessToken()
        async let third = manager.validAccessToken()
        let values = try await [first, second, third]
        let refreshCount = await broker.refreshCount
        let savedTokens = await store.load()

        XCTAssertEqual(values, Array(repeating: "new-synthetic", count: 3))
        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(savedTokens, rotated)
    }
}

private actor MemoryCredentialStore: CredentialStore {
    var tokens: OAuthTokens?
    init(tokens: OAuthTokens?) { self.tokens = tokens }
    func load() -> OAuthTokens? { tokens }
    func save(_ tokens: OAuthTokens) { self.tokens = tokens }
    func delete() { tokens = nil }
}

private actor CountingBroker: TokenBroker {
    private(set) var refreshCount = 0
    let result: OAuthTokens
    init(result: OAuthTokens) { self.result = result }
    func exchange(code: String, redirectURI: URL) throws -> OAuthTokens { result }
    func refresh(refreshToken: String) async throws -> OAuthTokens {
        refreshCount += 1
        try await Task.sleep(for: .milliseconds(25))
        return result
    }
}
