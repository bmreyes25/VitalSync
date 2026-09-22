import Foundation
import SwiftData

enum PersistenceDecision: Equatable, Sendable {
    case inserted
    case updated
    case duplicate
}

@ModelActor
actor PersistenceStore {
    func upsert(_ metric: NormalizedMetric, now: Date = .now) throws -> PersistenceDecision {
        let stableID = metric.id
        let descriptor = FetchDescriptor<StoredMetric>(predicate: #Predicate { $0.stableID == stableID })
        if let existing = try modelContext.fetch(descriptor).first {
            guard existing.fingerprint != metric.sourceFingerprint else { return .duplicate }
            existing.kindRawValue = metric.kind.rawValue
            existing.startDate = metric.startDate
            existing.endDate = metric.endDate
            existing.value = metric.value
            existing.unit = metric.unit
            existing.endpointRawValue = metric.sourceEndpoint.rawValue
            existing.fingerprint = metric.sourceFingerprint
            existing.encodedAttributes = try JSONEncoder().encode(metric.attributes)
            existing.updatedAt = now
            try modelContext.save()
            return .updated
        }
        let attributes = try JSONEncoder().encode(metric.attributes)
        modelContext.insert(StoredMetric(metric: metric, encodedAttributes: attributes, updatedAt: now))
        try modelContext.save()
        return .inserted
    }

    func hasCompleted(_ key: LedgerKey) throws -> Bool {
        let stableKey = key.stableValue
        let descriptor = FetchDescriptor<SyncLedgerEntry>(predicate: #Predicate { $0.stableKey == stableKey })
        return try modelContext.fetchCount(descriptor) > 0
    }

    func record(_ key: LedgerKey, outcome: SyncOutcome, destinationIdentifier: String? = nil) throws {
        guard try !hasCompleted(key) else { return }
        modelContext.insert(SyncLedgerEntry(key: key, outcome: outcome, destinationIdentifier: destinationIdentifier))
        try modelContext.save()
    }
}
