import Foundation
import SwiftData

@Model
final class StoredMetric {
    @Attribute(.unique) var stableID: String
    var sourceID: String
    var kindRawValue: String
    var startDate: Date
    var endDate: Date
    var value: Double?
    var unit: String?
    var endpointRawValue: String
    var fingerprint: String
    var encodedAttributes: Data
    var updatedAt: Date

    init(metric: NormalizedMetric, encodedAttributes: Data = Data("{}".utf8), updatedAt: Date = .now) {
        stableID = metric.id
        sourceID = metric.sourceID
        kindRawValue = metric.kind.rawValue
        startDate = metric.startDate
        endDate = metric.endDate
        value = metric.value
        unit = metric.unit
        endpointRawValue = metric.sourceEndpoint.rawValue
        fingerprint = metric.sourceFingerprint
        self.encodedAttributes = encodedAttributes
        self.updatedAt = updatedAt
    }
}

@Model
final class SyncLedgerEntry {
    @Attribute(.unique) var stableKey: String
    var endpointRawValue: String
    var sourceID: String
    var fingerprint: String
    var destinationRawValue: String
    var outcomeRawValue: String
    var completedAt: Date
    var destinationIdentifier: String?

    init(key: LedgerKey, outcome: SyncOutcome, destinationIdentifier: String? = nil, completedAt: Date = .now) {
        stableKey = key.stableValue
        endpointRawValue = key.endpoint.rawValue
        sourceID = key.sourceID
        fingerprint = key.sourceFingerprint
        destinationRawValue = key.destination.rawValue
        outcomeRawValue = outcome.rawValue
        self.completedAt = completedAt
        self.destinationIdentifier = destinationIdentifier
    }
}

enum SyncOutcome: String, Codable, Sendable {
    case inserted
    case updated
    case duplicate
    case skippedUnmappable
    case denied
    case failed
}

@Model
final class SyncCursor {
    @Attribute(.unique) var endpointRawValue: String
    var throughDate: Date
    var updatedAt: Date

    init(endpoint: OuraEndpoint, throughDate: Date, updatedAt: Date = .now) {
        endpointRawValue = endpoint.rawValue
        self.throughDate = throughDate
        self.updatedAt = updatedAt
    }
}

@Model
final class SyncRunRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var finishedAt: Date?
    var triggerRawValue: String
    var insertedCount: Int
    var updatedCount: Int
    var skippedCount: Int
    var failedCount: Int
    var redactedErrorCode: String?

    init(trigger: SyncTrigger, startedAt: Date = .now) {
        id = UUID()
        self.startedAt = startedAt
        triggerRawValue = trigger.rawValue
        insertedCount = 0
        updatedCount = 0
        skippedCount = 0
        failedCount = 0
    }
}

enum SyncTrigger: String, Codable, Sendable {
    case manual
    case foreground
    case background
    case backfill
}
