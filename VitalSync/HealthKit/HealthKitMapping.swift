import Foundation
import HealthKit

enum HealthKitMapping: Sendable, Equatable {
    case quantity(identifier: HKQuantityTypeIdentifier, unit: String)
    case category(identifier: HKCategoryTypeIdentifier)
    case workout
    case unsupported(reason: String)
}

struct HealthKitMappingPolicy: Sendable {
    func mapping(for kind: HealthMetricKind) -> HealthKitMapping {
        switch kind {
        case .activeEnergy:
            return .quantity(identifier: .activeEnergyBurned, unit: "kcal")
        case .restingEnergy:
            return .quantity(identifier: .basalEnergyBurned, unit: "kcal")
        case .steps:
            return .quantity(identifier: .stepCount, unit: "count")
        case .distance:
            return .quantity(identifier: .distanceWalkingRunning, unit: "m")
        case .heartRate:
            return .quantity(identifier: .heartRate, unit: "count/min")
        case .restingHeartRate:
            return .quantity(identifier: .restingHeartRate, unit: "count/min")
        case .respiratoryRate:
            return .quantity(identifier: .respiratoryRate, unit: "count/min")
        case .oxygenSaturation:
            return .quantity(identifier: .oxygenSaturation, unit: "%")
        case .vo2Max:
            return .quantity(identifier: .vo2Max, unit: "ml/kg*min")
        case .sleep:
            return .category(identifier: .sleepAnalysis)
        case .mindfulSession:
            return .category(identifier: .mindfulSession)
        case .workout:
            return .workout
        case .rmssd:
            return .unsupported(reason: "Oura RMSSD is not HealthKit SDNN")
        case .bodyTemperatureDeviation:
            return .unsupported(reason: "A deviation from baseline is not an absolute body temperature")
        case .readinessScore, .activityScore, .sleepScore, .stress, .resilience,
                .cardiovascularAge, .ringConfiguration, .tag:
            return .unsupported(reason: "No semantically equivalent HealthKit type")
        }
    }
}
