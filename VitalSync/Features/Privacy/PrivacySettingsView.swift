import SwiftUI
import SwiftData

struct PrivacySettingsView: View {
    let model: AppModel
    @Environment(\.modelContext) private var modelContext
    @AppStorage("vitalsync.exportHeartRateToHealth") private var exportToHealth = false
    @State private var showingHealthNotice = false
    @State private var confirmingDisconnect = false
    @State private var confirmingLocalDeletion = false
    @State private var deletionError = false

    var body: some View {
        ZStack {
            VitalBackground()

            ScrollView {
                VStack(spacing: 18) {
                    GlassEffectContainer(spacing: 8) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Apple Health", systemImage: "heart.fill")
                                    .font(.headline)
                                    .foregroundStyle(VitalPalette.coral)
                                Toggle("Write heart rate to Apple Health", isOn: $exportToHealth)
                                Text("Off by default. When enabled, VitalSync requests Health access during your next manual import. Oura data remains on this device.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Your data", systemImage: "hand.raised.fill")
                                    .font(.headline)
                                Text("Heart rate imports run only when you tap Import. You can remove VitalSync’s local records here at any time.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button("Manage Apple Health access") {
                                    showingHealthNotice = true
                                }
                                .buttonStyle(.glass)
                                Button("Delete local VitalSync data", role: .destructive) {
                                    confirmingLocalDeletion = true
                                }
                                .buttonStyle(.glass)
                            }
                        }

                        GlassCard {
                            VStack(spacing: 12) {
                                privacyRow("Analytics", value: "None")
                                Divider()
                                privacyRow("Advertising", value: "None")
                                Divider()
                                privacyRow("Oura password access", value: "Never")
                                Divider()
                                privacyRow("Oura client secret in app", value: "None")
                                Divider()
                                Link("Privacy policy", destination: URL(string: "https://bmreyes25.github.io/VitalSync/privacy.html")!)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        Button("Disconnect Oura", role: .destructive) {
                            confirmingDisconnect = true
                        }
                        .buttonStyle(.glass)
                        .disabled(model.connectionState != .connected)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(18)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Apple Health permissions", isPresented: $showingHealthNotice) {
            Button("Done", role: .cancel) {}
        } message: {
            Text("You can change VitalSync’s write permission in the Health app under your profile’s Apps and Services. VitalSync requests heart rate access when you run an import with export enabled.")
        }
        .alert("Local data could not be deleted", isPresented: $deletionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again. Your existing records are still on this device.")
        }
        .confirmationDialog("Delete local VitalSync data?", isPresented: $confirmingLocalDeletion, titleVisibility: .visible) {
            Button("Delete local data", role: .destructive) {
                deleteLocalData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes VitalSync’s local metrics and sync history from this device. Apple Health samples are managed separately in the Health app.")
        }
        .confirmationDialog("Disconnect Oura?", isPresented: $confirmingDisconnect, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) {
                Task { await model.disconnectFromOura() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the saved Oura credentials from this device. Locally retained metrics are not deleted.")
        }
    }

    private func privacyRow(_ title: String, value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .foregroundStyle(VitalPalette.success)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private func deleteLocalData() {
        do {
            try modelContext.delete(model: StoredMetric.self)
            try modelContext.delete(model: SyncLedgerEntry.self)
            try modelContext.delete(model: SyncCursor.self)
            try modelContext.delete(model: SyncRunRecord.self)
            try modelContext.save()
            model.resetLocalSyncState()
        } catch {
            modelContext.rollback()
            deletionError = true
        }
    }
}
