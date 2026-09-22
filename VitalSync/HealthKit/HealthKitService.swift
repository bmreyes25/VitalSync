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

actor HealthKitService: HealthDataWriting {
    private let store: HKHealthStore
    private let mappingPolicy: HealthKitMappingPolicy

    init(store: HKHealthStore = HKHealthStore(), mappingPolicy: HealthKitMappingPolicy = HealthKitMappingPolicy()) {
        self.store = store
        self.mappingPolicy = mappingPolicy
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: writableTypes(), read: [])
    }

    func write(_ metric: NormalizedMetric) async throws -> HealthKitWriteResult {
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
                metadata: metadata(for: metric)
            )
            try await replaceExistingSamples(type: type, metric: metric)
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
                metadata: metadata(for: metric)
            )
            try await replaceExistingSamples(type: type, metric: metric)
            try await store.save(sample)
            return .saved(destinationID: sample.uuid.uuidString)
        case .workout:
            return .unsupported(reason: "Workout route and activity mapping requires explicit source details")
        }
    }

    private func writableTypes() -> Set<HKSampleType> {
        Set(HealthMetricKind.allCases.compactMap { kind in
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

    private func metadata(for metric: NormalizedMetric) -> [String: Any] {
        [
            HKMetadataKeyExternalUUID: metric.id,
            HKMetadataKeySyncIdentifier: "vitalsync:\(metric.id)",
            HKMetadataKeySyncVersion: 1,
            "com.vitalsync.sourceEndpoint": metric.sourceEndpoint.rawValue,
            "com.vitalsync.sourceFingerprint": metric.sourceFingerprint
        ]
    }

    private func replaceExistingSamples(type: HKSampleType, metric: NormalizedMetric) async throws {
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeySyncIdentifier,
            allowedValues: ["vitalsync:\(metric.id)"]
        )
        let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples ?? []) }
            }
            store.execute(query)
        }
        if !samples.isEmpty { try await store.delete(samples) }
    }
}
