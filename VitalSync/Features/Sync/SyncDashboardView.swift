import SwiftUI
import SwiftData

struct SyncDashboardView: View {
    let model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @AppStorage("vitalsync.exportHeartRateToHealth") private var exportToHealth = false

    var body: some View {
        ZStack {
            VitalBackground()

            ScrollView {
                VStack(spacing: 18) {
                    hero

                    GlassEffectContainer(spacing: 8) {
                        connectionCard
                        syncCard
                        privacyCard
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("VitalSync")
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : .default, value: model.isSyncing)
        .animation(reduceMotion ? nil : .snappy, value: model.connectionState)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VitalIcon(symbol: "heart.text.clipboard.fill", tint: VitalPalette.coral)
                Spacer()
                StatusPill(title: "Private by design", isPositive: true)
            }

            Text("Your health, in sync.")
                .font(.largeTitle.bold())
                .fontDesign(.rounded)
                .accessibilityAddTraits(.isHeader)

            Text("Import recent Oura heart rate into a private local record. Choose whether compatible samples also go to Apple Health.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 12)
    }

    private var connectionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    VitalIcon(
                        symbol: model.connectionState == .connected ? "link.circle.fill" : "link.circle",
                        tint: model.connectionState == .connected ? VitalPalette.success : VitalPalette.accent
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Oura connection")
                            .font(.headline)
                        Text(model.connectionState.label)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                if model.connectionState != .connected {
                    Button {
                        Task { await model.connectToOura() }
                    } label: {
                        HStack {
                            Text(model.connectionState == .connecting ? "Opening Oura…" : "Connect to Oura")
                            Spacer()
                            if model.connectionState == .connecting {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.up.right")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(VitalPalette.accent)
                    .disabled(model.connectionState == .checking || model.connectionState == .connecting || model.connectionState == .unavailable)
                    .accessibilityHint("Opens Oura's secure sign-in page. VitalSync never sees your password or passkey.")
                }

                if let connectionMessage = model.connectionMessage {
                    Label(connectionMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(VitalPalette.coral)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("ouraConnectionMessage")
                } else if model.connectionState != .connected {
                    Label("Passwords and passkeys stay inside Apple's secure browser.", systemImage: "key.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var syncCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    VitalIcon(symbol: "arrow.triangle.2.circlepath", tint: VitalPalette.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Latest sync")
                            .font(.headline)
                        Text(model.lastSyncDate?.formatted(date: .abbreviated, time: .shortened) ?? "Not synced yet")
                            .foregroundStyle(.secondary)
                    }
                }

                Text(model.lastSyncSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if model.connectionState == .connected {
                    Button {
                        Task {
                            await model.importHeartRate(
                                into: modelContext.container,
                                exportToHealth: exportToHealth
                            )
                        }
                    } label: {
                        HStack {
                            Label(model.isSyncing ? "Importing…" : "Import last 7 days", systemImage: "arrow.down.heart")
                            Spacer()
                            if model.isSyncing { ProgressView() }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(VitalPalette.accent)
                    .disabled(model.isSyncing)
                    .accessibilityHint("Imports recent Oura heart rate. Apple Health export follows your Privacy setting.")
                }

                if let syncErrorMessage = model.syncErrorMessage {
                    Label(syncErrorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(VitalPalette.coral)
                        .fixedSize(horizontal: false, vertical: true)
                }

                #if DEBUG
                Button {
                    Task { await model.runSyntheticPreviewSync() }
                } label: {
                    Label(model.isSyncing ? "Running preview…" : "Run synthetic preview", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .disabled(model.isSyncing)
                .accessibilityHint("Uses fabricated data and does not access Apple Health or Oura")
                #endif
            }
        }
    }

    private var privacyCard: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 14) {
                VitalIcon(symbol: "lock.shield.fill", tint: VitalPalette.success)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Private by design")
                        .font(.headline)
                    Text("Credentials stay in Keychain. VitalSync only writes measurements with a matching Apple Health meaning.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
