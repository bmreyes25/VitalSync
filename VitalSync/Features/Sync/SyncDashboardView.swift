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
                LabeledContent("Oura", value: model.connectionState.label)
                LabeledContent("Last sync", value: model.lastSyncDate?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                Text(model.lastSyncSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if model.connectionState != .connected {
                Section {
                    Button {
                        Task { await model.connectToOura() }
                    } label: {
                        HStack {
                            Label("Connect to Oura", systemImage: "link")
                            Spacer()
                            if model.connectionState == .connecting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(model.connectionState == .checking || model.connectionState == .connecting || model.connectionState == .unavailable)
                    .accessibilityHint("Opens Oura's secure sign-in page. VitalSync never sees your password or passkey.")

                    if let connectionMessage = model.connectionMessage {
                        Label(connectionMessage, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("ouraConnectionMessage")
                    }
                } footer: {
                    Text("Oura sign-in uses the system browser, including saved passwords and passkeys supported by Oura.")
                }
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
            }
        }
        .navigationTitle("VitalSync")
        .animation(reduceMotion ? nil : .default, value: model.isSyncing)
    }
}
