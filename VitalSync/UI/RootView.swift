import SwiftUI

struct RootView: View {
    let model: AppModel

    var body: some View {
        TabView {
            NavigationStack { DashboardView(model: model) }
                .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }

            NavigationStack { DataView() }
                .tabItem { Label("Data", systemImage: "waveform.path.ecg") }

            NavigationStack { PrivacyView(model: model) }
                .tabItem { Label("Privacy", systemImage: "hand.raised.fill") }
        }
        .tint(.blue)
    }
}

private struct DashboardView: View {
    let model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "heart.text.clipboard")
                        .font(.system(size: 42))
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                    Text("Private health syncing")
                        .font(.title2.bold())
                    Text("Oura data stays under your control. Only compatible measurements are eligible for Apple Health.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Status") {
                LabeledContent("Oura", value: model.connectionState == .connected ? "Connected" : "Not connected")
                LabeledContent("Last sync", value: model.lastSyncDate?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                Text(model.lastSyncSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    Task { await model.runSyntheticPreviewSync() }
                } label: {
                    HStack {
                        Text(model.isSyncing ? "Syncing…" : "Run synthetic preview")
                        Spacer()
                        if model.isSyncing { ProgressView() }
                    }
                }
                .disabled(model.isSyncing)
                .accessibilityHint("Uses fabricated data and does not access Apple Health or Oura")
            } footer: {
                Text("Live connection remains disabled until you configure your own token broker.")
            }
        }
        .navigationTitle("VitalSync")
        .animation(reduceMotion ? nil : .default, value: model.isSyncing)
    }
}

private struct DataView: View {
    var body: some View {
        ContentUnavailableView(
            "No imported data",
            systemImage: "waveform.path.ecg",
            description: Text("Authorized Oura records will appear here after a successful sync.")
        )
        .navigationTitle("Data")
    }
}

private struct PrivacyView: View {
    let model: AppModel
    @State private var exportToHealth = true

    var body: some View {
        Form {
            Section("Apple Health") {
                Toggle("Export compatible metrics", isOn: $exportToHealth)
                Text("RMSSD, proprietary scores, stress, resilience, and other unmatched metrics remain local.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Privacy") {
                LabeledContent("Analytics", value: "None")
                LabeledContent("Advertising", value: "None")
                LabeledContent("Secrets in app", value: "None")
            }
            Section {
                Button("Disconnect Oura", role: .destructive) {
                    model.connectionState = .disconnected
                }
                .disabled(model.connectionState == .disconnected)
            }
        }
        .navigationTitle("Privacy")
    }
}

#Preview {
    RootView(model: AppModel())
}
