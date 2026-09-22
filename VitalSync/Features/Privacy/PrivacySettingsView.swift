import SwiftUI

struct PrivacySettingsView: View {
    let model: AppModel
    @State private var exportToHealth = true
    @State private var showingTransferNotice = false

    var body: some View {
        Form {
            Section("Apple Health") {
                Toggle("Export compatible metrics", isOn: $exportToHealth)
                Text("RMSSD, proprietary scores, stress, resilience, and other unmatched metrics remain local.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Import and export") {
                Button("Review transfer protections") {
                    showingTransferNotice = true
                }
                Text("Transfers are user-initiated, validated, protected while the device is locked, and excluded from backups while temporary.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                LabeledContent("Analytics", value: "None")
                LabeledContent("Advertising", value: "None")
                LabeledContent("Oura password access", value: "Never")
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
        .alert("Protected health-data transfers", isPresented: $showingTransferNotice) {
            Button("Done", role: .cancel) {}
        } message: {
            Text("VitalSync asks for confirmation for each transfer. Imports are checked before processing, and exports use iOS complete file protection until you choose a destination.")
        }
    }
}
