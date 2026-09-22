import Foundation
import SwiftData
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

    @Test func manualImportPersistsSyntheticHeartRateWithoutHealthAccessAndIsIdempotent() async throws {
        let container = try ModelContainer(
            for: StoredMetric.self, SyncLedgerEntry.self, SyncCursor.self, SyncRunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = InMemoryCredentialStore(tokens: .synthetic)
        let timestamp = Date(timeIntervalSince1970: 1_893_553_445)
        let client = SyntheticHeartRateClient(samples: [
            OuraHeartRate(bpm: 63, source: "synthetic", timestamp: timestamp, timestampUnix: 1_893_553_445_000)
        ])
        let model = AppModel(authenticator: StubAuthenticator(), credentialStore: store, heartRateClient: client)
        await model.restoreConnectionState()

        await model.importHeartRate(into: container, exportToHealth: false)
        #expect(model.lastSyncSummary.contains("1 new"))
        #expect(model.syncErrorMessage == nil)

        await model.importHeartRate(into: container, exportToHealth: false)
        #expect(model.lastSyncSummary.contains("1 already saved"))

        let metrics = try container.mainContext.fetch(FetchDescriptor<StoredMetric>())
        #expect(metrics.count == 1)
        #expect(metrics.first?.value == 63)
    }
}

private struct SyntheticHeartRateClient: OuraHeartRateFetching {
    let samples: [OuraHeartRate]

    func fetchHeartRates(from startDate: Date, through endDate: Date) async throws -> [OuraHeartRate] {
        samples
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
