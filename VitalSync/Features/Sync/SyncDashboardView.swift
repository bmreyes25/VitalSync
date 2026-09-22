import SwiftUI

struct SyncDashboardView: View {
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
