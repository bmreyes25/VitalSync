import Foundation

enum OuraExportEligibility: Equatable, Sendable {
    case eligible
    case alreadyAvailableFromOura
    case needsSemanticReview(String)
    case noHealthKitEquivalent
}

/// A second gate after HealthKit type mapping. A matching HealthKit identifier alone
/// does not mean VitalSync should export a metric Oura already shares or a value
/// whose source timing and measurement method are not sufficiently specified.
struct OuraExportGapPolicy: Sendable {
    func eligibility(for kind: HealthMetricKind) -> OuraExportEligibility {
        switch kind {
        case .activeEnergy, .steps, .heartRate, .respiratoryRate, .sleep, .workout, .mindfulSession:
            return .alreadyAvailableFromOura
        case .oxygenSaturation:
            return .needsSemanticReview("Oura's daily average lacks an exact measurement interval")
        case .vo2Max:
            return .needsSemanticReview("Oura's API does not identify the estimate method")
        case .restingEnergy, .distance, .restingHeartRate:
            return .needsSemanticReview("Source interval or category equivalence is not established")
        case .rmssd, .bodyTemperatureDeviation, .readinessScore, .activityScore,
             .sleepScore, .stress, .resilience, .cardiovascularAge, .ringConfiguration, .tag:
            return .noHealthKitEquivalent
        }
    }
}
