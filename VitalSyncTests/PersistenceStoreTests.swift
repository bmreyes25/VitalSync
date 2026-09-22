import SwiftData
import XCTest
@testable import VitalSync

final class PersistenceStoreTests: XCTestCase {
    func testUpsertIsDeterministicAndRecognizesSourceRevision() async throws {
        let container = try ModelContainer(
            for: StoredMetric.self, SyncLedgerEntry.self, SyncCursor.self, SyncRunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = PersistenceStore(modelContainer: container)
        let original = fixture(fingerprint: "revision-a", value: 10)
        let revised = fixture(fingerprint: "revision-b", value: 11)

        let inserted = try await store.upsert(original)
        let duplicate = try await store.upsert(original)
        let updated = try await store.upsert(revised)
        XCTAssertEqual(inserted, .inserted)
        XCTAssertEqual(duplicate, .duplicate)
        XCTAssertEqual(updated, .updated)
    }

    func testLedgerDoesNotDuplicateCompletedDestination() async throws {
        let container = try ModelContainer(
            for: StoredMetric.self, SyncLedgerEntry.self, SyncCursor.self, SyncRunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = PersistenceStore(modelContainer: container)
        let key = LedgerKey(source: "oura-v2", endpoint: .dailyActivity, sourceID: "synthetic-1", sourceFingerprint: "revision-a", destination: .healthKit)

        try await store.record(key, outcome: .inserted, destinationIdentifier: "synthetic-hk-id")
        try await store.record(key, outcome: .inserted, destinationIdentifier: "different-id")

        let completed = try await store.hasCompleted(key)
        XCTAssertTrue(completed)
    }

    private func fixture(fingerprint: String, value: Double) -> NormalizedMetric {
        NormalizedMetric(
            sourceID: "synthetic-1", kind: .steps, startDate: .distantPast, endDate: .distantPast,
            value: value, unit: "count", sourceEndpoint: .dailyActivity,
            sourceFingerprint: fingerprint, attributes: [:]
        )
    }
}
