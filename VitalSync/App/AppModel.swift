import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum ConnectionState: Equatable {
        case disconnected
        case connected
    }

    var connectionState: ConnectionState = .disconnected
    var isSyncing = false
    var lastSyncDate: Date?
    var lastSyncSummary = "No syncs yet"

    func runSyntheticPreviewSync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        try? await Task.sleep(for: .milliseconds(500))
        lastSyncDate = .now
        lastSyncSummary = "Synthetic preview completed — no health data accessed"
    }
}
