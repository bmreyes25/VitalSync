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
    private let heartRateClient: (any OuraHeartRateFetching)?

    init(
        authenticator: (any OAuthAuthorizing)? = nil,
        credentialStore: (any CredentialStore)? = nil,
        heartRateClient: (any OuraHeartRateFetching)? = nil,
        configurationIssue: String? = nil
    ) {
        self.authenticator = authenticator
        self.credentialStore = credentialStore
        self.heartRateClient = heartRateClient
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
                heartRateClient: OuraClient(tokenManager: tokenManager)
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
        connectionState = .connecting
        connectionMessage = nil

        do {
            try await authenticator.connect()
            connectionState = .connected
        } catch AuthenticationError.userCancelled {
            connectionState = .disconnected
        } catch AuthenticationError.stateMismatch {
            connectionState = .disconnected
            connectionMessage = "The secure sign-in response could not be verified. Please try again."
        } catch {
            connectionState = .disconnected
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

    func importHeartRate(into container: ModelContainer, exportToHealth: Bool) async {
        guard connectionState == .connected, !isSyncing, let heartRateClient else { return }
        isSyncing = true
        syncErrorMessage = nil
        defer { isSyncing = false }

        do {
            let endDate = Date()
            let startDate = endDate.addingTimeInterval(-7 * 24 * 60 * 60)
            let samples = try await heartRateClient.fetchHeartRates(from: startDate, through: endDate)
            try Task.checkCancellation()
            let normalizer = HeartRateNormalizer()
            let metrics = samples.compactMap { normalizer.normalize($0) }
            let writer = HealthKitService()
            var canExport = exportToHealth
            if exportToHealth && !metrics.isEmpty {
                do {
                    try await writer.requestAuthorization()
                } catch {
                    canExport = false
                    syncErrorMessage = "Heart rate was saved locally, but Apple Health access could not be requested. Check Health permissions and try again."
                }
            }
            let engine = SyncEngine(persistence: PersistenceStore(modelContainer: container), healthWriter: writer)
            let summary = await engine.reconcile(metrics, exportToHealth: canExport)
            lastSyncDate = endDate
            lastSyncSummary = "\(summary.inserted) new, \(summary.updated) updated, \(summary.duplicates) already saved"
            if canExport {
                lastSyncSummary += ", \(summary.exported) written to Apple Health"
            }
            if summary.denied > 0 || summary.failures > 0 {
                syncErrorMessage = "Some records could not be written. Check Apple Health permissions and try again."
            }
        } catch is CancellationError {
            return
        } catch OuraAPIError.unauthorized {
            syncErrorMessage = "Oura access expired. Disconnect and connect again to renew permission."
        } catch OuraAPIError.rateLimited {
            syncErrorMessage = "Oura is limiting requests. Please try again later."
        } catch {
            syncErrorMessage = "Could not import heart rate. Check your connection and try again."
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
