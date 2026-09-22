import SwiftData
import SwiftUI

@main
struct VitalSyncApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            PrivacyShield {
                RootView(model: model)
            }
        }
        .modelContainer(for: [StoredMetric.self, SyncLedgerEntry.self, SyncCursor.self, SyncRunRecord.self])
    }
}
