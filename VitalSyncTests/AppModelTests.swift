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

    @Test func cancellingPermissionUpdateKeepsExistingConnection() async {
        let store = InMemoryCredentialStore(tokens: .synthetic)
        let model = AppModel(
            authenticator: StubAuthenticator { throw AuthenticationError.userCancelled },
            credentialStore: store
        )
        await model.restoreConnectionState()

        await model.connectToOura()

        #expect(model.connectionState == .connected)
        #expect(await store.load() == .synthetic)
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
        let model = AppModel(authenticator: StubAuthenticator(), credentialStore: store, healthDataClient: client)
        await model.restoreConnectionState()

        await model.importRecentData(into: container)
        #expect(model.lastSyncSummary.contains("1 new"))
        #expect(model.syncErrorMessage == nil)

        await model.importRecentData(into: container)
        #expect(model.lastSyncSummary.contains("1 already saved"))

        let metrics = try container.mainContext.fetch(FetchDescriptor<StoredMetric>())
        #expect(metrics.count == 1)
        #expect(metrics.first?.value == 63)
    }

    @Test func importsThreeSyntheticWellnessKindsLocallyWithoutHealthWrites() async throws {
        let container = try ModelContainer(
            for: StoredMetric.self, SyncLedgerEntry.self, SyncCursor.self, SyncRunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let client = SyntheticHeartRateClient(
            samples: [],
            sleeps: [OuraSleepPeriod(id: "synthetic-sleep-1", day: "2030-01-02", bedtimeStart: "2030-01-01T23:00:00-08:00", bedtimeEnd: "2030-01-02T07:00:00-08:00", averageHRV: 41)],
            readiness: [OuraDailyReadiness(id: "synthetic-ready-1", day: "2030-01-02", timestamp: nil, temperatureDeviation: -0.3)],
            oxygen: [OuraSpO2(id: "synthetic-spo2-1", day: "2030-01-02", spo2Percentage: .init(average: 96.4))]
        )
        let model = AppModel(
            authenticator: StubAuthenticator(), credentialStore: InMemoryCredentialStore(tokens: .synthetic),
            healthDataClient: client
        )
        await model.restoreConnectionState()

        await model.importRecentData(into: container)
        let records = try container.mainContext.fetch(FetchDescriptor<StoredMetric>())
        let healthWrites = try container.mainContext.fetch(FetchDescriptor<SyncLedgerEntry>())
            .filter { $0.destinationRawValue == SyncDestination.healthKit.rawValue }

        #expect(Set(records.map(\.kindRawValue)) == Set([
            HealthMetricKind.rmssd.rawValue,
            HealthMetricKind.bodyTemperatureDeviation.rawValue,
            HealthMetricKind.oxygenSaturation.rawValue
        ]))
        #expect(healthWrites.isEmpty)
    }

    @Test func deniedSpO2ScopeDoesNotDiscardOtherImports() async throws {
        let container = try ModelContainer(
            for: StoredMetric.self, SyncLedgerEntry.self, SyncCursor.self, SyncRunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let timestamp = Date(timeIntervalSince1970: 1_893_553_445)
        let client = SyntheticHeartRateClient(
            samples: [OuraHeartRate(bpm: 63, source: "synthetic", timestamp: timestamp, timestampUnix: 1_893_553_445_000)],
            denyOxygen: true
        )
        let model = AppModel(
            authenticator: StubAuthenticator(), credentialStore: InMemoryCredentialStore(tokens: .synthetic),
            healthDataClient: client
        )
        await model.restoreConnectionState()

        await model.importRecentData(into: container)

        #expect(try container.mainContext.fetchCount(FetchDescriptor<StoredMetric>()) == 1)
        #expect(model.syncErrorMessage?.contains("Update Oura permissions") == true)
    }
}

private struct SyntheticHeartRateClient: OuraHealthDataFetching {
    let samples: [OuraHeartRate]
    var sleeps: [OuraSleepPeriod] = []
    var readiness: [OuraDailyReadiness] = []
    var oxygen: [OuraSpO2] = []
    var denyOxygen = false

    func fetchHeartRates(from startDate: Date, through endDate: Date) async throws -> [OuraHeartRate] {
        samples
    }

    func fetchSleepPeriods(from startDate: Date, through endDate: Date) async throws -> [OuraSleepPeriod] { sleeps }
    func fetchDailyReadiness(from startDate: Date, through endDate: Date) async throws -> [OuraDailyReadiness] { readiness }
    func fetchDailySpO2(from startDate: Date, through endDate: Date) async throws -> [OuraSpO2] {
        if denyOxygen { throw OuraAPIError.status(403) }
        return oxygen
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
