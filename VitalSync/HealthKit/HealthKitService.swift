import Foundation
import HealthKit

enum HealthKitWriteResult: Equatable, Sendable {
    case saved(destinationID: String)
    case denied
    case unsupported(reason: String)
}

protocol HealthDataWriting: Sendable {
    func requestAuthorization() async throws
    func write(_ metric: NormalizedMetric) async throws -> HealthKitWriteResult
}

struct HealthSyncVersionSequencer: Sendable {
    private(set) var lastVersion: Int64 = 0

    mutating func next(at date: Date) -> Int64 {
        let now = Int64((date.timeIntervalSince1970 * 1_000).rounded())
        lastVersion = max(now, lastVersion + 1)
        return lastVersion
    }
}

actor HealthKitService: HealthDataWriting {
    private let store: HKHealthStore
    private let mappingPolicy: HealthKitMappingPolicy
    private let exportGapPolicy: OuraExportGapPolicy
    private var versionSequencer = HealthSyncVersionSequencer()

    init(
        store: HKHealthStore = HKHealthStore(),
        mappingPolicy: HealthKitMappingPolicy = HealthKitMappingPolicy(),
        exportGapPolicy: OuraExportGapPolicy = OuraExportGapPolicy()
    ) {
        self.store = store
        self.mappingPolicy = mappingPolicy
        self.exportGapPolicy = exportGapPolicy
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let types = writableTypes()
        guard !types.isEmpty else { return }
        try await store.requestAuthorization(toShare: types, read: [])
    }

    func write(_ metric: NormalizedMetric) async throws -> HealthKitWriteResult {
        switch exportGapPolicy.eligibility(for: metric.kind) {
        case .eligible: break
        case .alreadyAvailableFromOura:
            return .unsupported(reason: "Oura already offers this Apple Health export")
        case .needsSemanticReview(let reason):
            return .unsupported(reason: reason)
        case .noHealthKitEquivalent:
            return .unsupported(reason: "No semantically equivalent HealthKit type")
        }
        switch mappingPolicy.mapping(for: metric.kind) {
        case .unsupported(let reason):
            return .unsupported(reason: reason)
        case .quantity(let identifier, let unitString):
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier),
                  store.authorizationStatus(for: type) == .sharingAuthorized else { return .denied }
            guard let value = metric.value else { return .unsupported(reason: "Missing quantity") }
            let unit = HKUnit(from: unitString)
            let sample = HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: value),
                start: metric.startDate,
                end: metric.endDate,
                metadata: metadata(for: metric, syncVersion: nextSyncVersion())
            )
            try await store.save(sample)
            return .saved(destinationID: sample.uuid.uuidString)
        case .category(let identifier):
            guard let type = HKCategoryType.categoryType(forIdentifier: identifier),
                  store.authorizationStatus(for: type) == .sharingAuthorized else { return .denied }
            let value = categoryValue(for: metric, identifier: identifier)
            let sample = HKCategorySample(
                type: type,
                value: value,
                start: metric.startDate,
                end: metric.endDate,
                metadata: metadata(for: metric, syncVersion: nextSyncVersion())
            )
            try await store.save(sample)
            return .saved(destinationID: sample.uuid.uuidString)
        case .workout:
            return .unsupported(reason: "Workout route and activity mapping requires explicit source details")
        }
    }

    private func writableTypes() -> Set<HKSampleType> {
        Set(HealthMetricKind.allCases.compactMap { kind in
            guard exportGapPolicy.eligibility(for: kind) == .eligible else { return nil }
            switch mappingPolicy.mapping(for: kind) {
            case .quantity(let identifier, _): return HKQuantityType.quantityType(forIdentifier: identifier)
            case .category(let identifier): return HKCategoryType.categoryType(forIdentifier: identifier)
            case .workout: return HKObjectType.workoutType()
            case .unsupported: return nil
            }
        })
    }

    private func categoryValue(for metric: NormalizedMetric, identifier: HKCategoryTypeIdentifier) -> Int {
        if identifier == .sleepAnalysis { return HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue }
        if identifier == .mindfulSession { return HKCategoryValue.notApplicable.rawValue }
        return Int(metric.value ?? 0)
    }

    private func metadata(for metric: NormalizedMetric, syncVersion: Int64) -> [String: Any] {
        [
            HKMetadataKeyExternalUUID: metric.id,
            HKMetadataKeySyncIdentifier: "vitalsync:\(metric.id)",
            HKMetadataKeySyncVersion: syncVersion,
            "com.vitalsync.sourceEndpoint": metric.sourceEndpoint.rawValue,
            "com.vitalsync.sourceFingerprint": metric.sourceFingerprint
        ]
    }

    private func nextSyncVersion() -> Int64 {
        // HealthKit replaces a sample with the same sync identifier only when its
        // new version is greater. Epoch milliseconds make versions advance across
        // launches; the actor counter keeps rapid writes monotonic within a run.
        versionSequencer.next(at: .now)
    }
}
