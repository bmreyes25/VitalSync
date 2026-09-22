import Foundation

struct SyncSummary: Equatable, Sendable {
    var inserted = 0
    var updated = 0
    var duplicates = 0
    var exported = 0
    var skipped = 0
    var denied = 0
    var failures = 0
}

actor SyncEngine {
    private let persistence: PersistenceStore
    private let healthWriter: any HealthDataWriting

    init(persistence: PersistenceStore, healthWriter: any HealthDataWriting) {
        self.persistence = persistence
        self.healthWriter = healthWriter
    }

    func reconcile(_ metrics: [NormalizedMetric], exportToHealth: Bool) async -> SyncSummary {
        var summary = SyncSummary()
        for metric in metrics {
            guard !Task.isCancelled else { break }
            do {
                switch try await persistence.upsert(metric) {
                case .inserted: summary.inserted += 1
                case .updated: summary.updated += 1
                case .duplicate: summary.duplicates += 1
                }

                let localKey = LedgerKey(
                    source: "oura-v2", endpoint: metric.sourceEndpoint, sourceID: metric.sourceID,
                    sourceFingerprint: metric.sourceFingerprint, destination: .local
                )
                try await persistence.record(localKey, outcome: .inserted)
                guard exportToHealth else { continue }

                let healthKey = LedgerKey(
                    source: "oura-v2", endpoint: metric.sourceEndpoint, sourceID: metric.sourceID,
                    sourceFingerprint: metric.sourceFingerprint, destination: .healthKit
                )
                guard try await !persistence.hasCompleted(healthKey) else {
                    summary.duplicates += 1
                    continue
                }
                switch try await healthWriter.write(metric) {
                case .saved(let id):
                    try await persistence.record(healthKey, outcome: .inserted, destinationIdentifier: id)
                    summary.exported += 1
                case .denied:
                    summary.denied += 1
                case .unsupported:
                    try await persistence.record(healthKey, outcome: .skippedUnmappable)
                    summary.skipped += 1
                }
            } catch {
                summary.failures += 1
            }
        }
        return summary
    }
}
