import Foundation
import Observation

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

    private let authenticator: (any OAuthAuthorizing)?
    private let credentialStore: (any CredentialStore)?

    init(
        authenticator: (any OAuthAuthorizing)? = nil,
        credentialStore: (any CredentialStore)? = nil,
        configurationIssue: String? = nil
    ) {
        self.authenticator = authenticator
        self.credentialStore = credentialStore
        connectionState = authenticator == nil || credentialStore == nil ? .unavailable : .checking
        connectionMessage = configurationIssue
    }

    static func live(bundle: Bundle = .main) -> AppModel {
        do {
            let configuration = try AppConfiguration.load(bundle: bundle)
            let credentialStore = KeychainCredentialStore()
            let broker = BrokerClient(baseURL: configuration.tokenBrokerBaseURL)
            let authenticator = OAuthCoordinator(
                configuration: .live(appConfiguration: configuration),
                broker: broker,
                credentialStore: credentialStore
            )
            return AppModel(authenticator: authenticator, credentialStore: credentialStore)
        } catch {
            return AppModel(configurationIssue: "VitalSync needs its secure Oura connection settings before sign-in can begin.")
        }
    }

    func restoreConnectionState() async {
        guard connectionState == .checking, let credentialStore else { return }
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

    func runSyntheticPreviewSync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        try? await Task.sleep(for: .milliseconds(500))
        lastSyncDate = .now
        lastSyncSummary = "Synthetic preview completed — no health data accessed"
    }
}
