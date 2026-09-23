import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppModel {
    enum ConnectionState: Equatable {
        case checking
        case disconnected
        case connecting
        case connected
        case unavailable

        var label: String {
            switch self {
            case .checking: "Checking…"
            case .disconnected: "Not connected"
            case .connecting: "Connecting…"
            case .connected: "Connected"
            case .unavailable: "Setup required"
            }
        }
    }

    var connectionState: ConnectionState
    var connectionMessage: String?
    var isSyncing = false
    var lastSyncDate: Date?
    var lastSyncSummary = "No syncs yet"
    var syncErrorMessage: String?

    private let authenticator: (any OAuthAuthorizing)?
    private let credentialStore: (any CredentialStore)?
    private let healthDataClient: (any OuraHealthDataFetching)?

    init(
        authenticator: (any OAuthAuthorizing)? = nil,
        credentialStore: (any CredentialStore)? = nil,
        healthDataClient: (any OuraHealthDataFetching)? = nil,
        configurationIssue: String? = nil
    ) {
        self.authenticator = authenticator
        self.credentialStore = credentialStore
        self.healthDataClient = healthDataClient
        connectionState = authenticator == nil || credentialStore == nil ? .unavailable : .checking
        connectionMessage = configurationIssue
    }

    static func live(bundle: Bundle = .main) -> AppModel {
        do {
            let configuration = try AppConfiguration.load(bundle: bundle)
            let credentialStore = KeychainCredentialStore()
            let broker = BrokerClient(baseURL: configuration.tokenBrokerBaseURL)
            let tokenManager = TokenManager(store: credentialStore, broker: broker)
            let authenticator = OAuthCoordinator(
                configuration: .live(appConfiguration: configuration),
                broker: broker,
                credentialStore: credentialStore
            )
            return AppModel(
                authenticator: authenticator,
                credentialStore: credentialStore,
                healthDataClient: OuraClient(tokenManager: tokenManager)
            )
        } catch {
            return AppModel(configurationIssue: "VitalSync needs its secure Oura connection settings before sign-in can begin.")
        }
    }

    func restoreConnectionState() async {
        guard connectionState == .checking, let credentialStore else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SyntheticStoreScreenshots") {
            connectionState = .disconnected
            connectionMessage = nil
            return
        }
        #endif
        do {
            connectionState = try await credentialStore.load() == nil ? .disconnected : .connected
        } catch {
            connectionState = .disconnected
            connectionMessage = "VitalSync could not read the saved connection. Try connecting again."
        }
    }

    func connectToOura() async {
        guard connectionState != .connecting, let authenticator else { return }
        let wasConnected = connectionState == .connected
        connectionState = .connecting
        connectionMessage = nil

        do {
            try await authenticator.connect()
            connectionState = .connected
        } catch AuthenticationError.userCancelled {
            connectionState = wasConnected ? .connected : .disconnected
        } catch AuthenticationError.stateMismatch {
            connectionState = wasConnected ? .connected : .disconnected
            connectionMessage = "The secure sign-in response could not be verified. Please try again."
        } catch {
            connectionState = wasConnected ? .connected : .disconnected
            connectionMessage = "Oura sign-in did not finish. Check your connection and try again."
        }
    }

    func disconnectFromOura() async {
        guard let credentialStore else { return }
        do {
            try await credentialStore.delete()
            connectionState = .disconnected
            connectionMessage = nil
        } catch {
            connectionMessage = "VitalSync could not remove the saved connection. Please try again."
        }
    }

    func importRecentData(into container: ModelContainer) async {
        guard connectionState == .connected, !isSyncing, let healthDataClient else { return }
        isSyncing = true
        syncErrorMessage = nil
        defer { isSyncing = false }

        do {
            let endDate = Date()
            let startDate = endDate.addingTimeInterval(-7 * 24 * 60 * 60)
            var metrics: [NormalizedMetric] = []
            var failedCategories: [String] = []
            var needsPermissionUpdate = false
            var successfulRequests = 0
            let wellness = OuraWellnessNormalizer()

            do {
                let samples = try await healthDataClient.fetchHeartRates(from: startDate, through: endDate)
                metrics += samples.compactMap { HeartRateNormalizer().normalize($0) }
                successfulRequests += 1
            } catch {
                failedCategories.append("heart rate")
                if case OuraAPIError.status(403) = error { needsPermissionUpdate = true }
            }
            try Task.checkCancellation()

            do {
                let samples = try await healthDataClient.fetchSleepPeriods(from: startDate, through: endDate)
                metrics += samples.compactMap { wellness.normalize($0) }
                successfulRequests += 1
            } catch {
                failedCategories.append("sleep HRV")
                if case OuraAPIError.status(403) = error { needsPermissionUpdate = true }
            }
            try Task.checkCancellation()

            do {
                let samples = try await healthDataClient.fetchDailyReadiness(from: startDate, through: endDate)
                metrics += samples.compactMap { wellness.normalize($0) }
                successfulRequests += 1
            } catch {
                failedCategories.append("temperature deviation")
                if case OuraAPIError.status(403) = error { needsPermissionUpdate = true }
            }
            try Task.checkCancellation()

            do {
                let samples = try await healthDataClient.fetchDailySpO2(from: startDate, through: endDate)
                metrics += samples.compactMap { wellness.normalize($0) }
                successfulRequests += 1
            } catch {
                failedCategories.append("sleep SpO₂")
                if case OuraAPIError.status(403) = error { needsPermissionUpdate = true }
            }
            try Task.checkCancellation()

            guard successfulRequests > 0 else {
                syncErrorMessage = needsPermissionUpdate
                    ? "Oura needs updated permissions. Tap Update Oura permissions, then import again."
                    : "Could not reach the Oura categories. Check your connection and try again."
                return
            }
            let writer = HealthKitService()
            let engine = SyncEngine(persistence: PersistenceStore(modelContainer: container), healthWriter: writer)
            let summary = await engine.reconcile(metrics, exportToHealth: false)
            lastSyncDate = endDate
            lastSyncSummary = "\(summary.inserted) new, \(summary.updated) updated, \(summary.duplicates) already saved"
            if !failedCategories.isEmpty {
                syncErrorMessage = needsPermissionUpdate
                    ? "Some categories need Oura permission. Tap Update Oura permissions, then import again."
                    : "Some categories could not be imported. Try again later."
            } else if summary.failures > 0 {
                syncErrorMessage = "Some records could not be saved locally. Please try again."
            }
        } catch is CancellationError {
            return
        } catch OuraAPIError.unauthorized {
            syncErrorMessage = "Oura access expired. Disconnect and connect again to renew permission."
        } catch OuraAPIError.rateLimited {
            syncErrorMessage = "Oura is limiting requests. Please try again later."
        } catch {
            syncErrorMessage = "Could not import Oura data. Check your connection and try again."
        }
    }

    func runSyntheticPreviewSync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        try? await Task.sleep(for: .milliseconds(500))
        lastSyncDate = .now
        lastSyncSummary = "Synthetic preview completed — no health data accessed"
    }

    func resetLocalSyncState() {
        lastSyncDate = nil
        lastSyncSummary = "No syncs yet"
        syncErrorMessage = nil
    }
}
