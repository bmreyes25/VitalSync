import SwiftUI

struct RootView: View {
    let model: AppModel

    var body: some View {
        TabView {
            NavigationStack { SyncDashboardView(model: model) }
                .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }

            NavigationStack { LocalDataView() }
                .tabItem { Label("Data", systemImage: "waveform.path.ecg") }

            NavigationStack { PrivacySettingsView(model: model) }
                .tabItem { Label("Privacy", systemImage: "hand.raised.fill") }
        }
        .tint(.blue)
        .task {
            await model.restoreConnectionState()
        }
    }
}

#Preview {
    RootView(model: AppModel(configurationIssue: "Preview configuration"))
}
