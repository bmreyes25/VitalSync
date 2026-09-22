import Foundation

enum HealthMetricKind: String, Codable, CaseIterable, Sendable {
    case activeEnergy
    case restingEnergy
    case steps
    case distance
    case heartRate
    case restingHeartRate
    case respiratoryRate
    case oxygenSaturation
    case bodyTemperatureDeviation
    case sleep
    case workout
    case mindfulSession
    case rmssd
    case readinessScore
    case activityScore
    case sleepScore
    case stress
    case resilience
    case cardiovascularAge
    case vo2Max
    case ringConfiguration
    case tag
}

struct NormalizedMetric: Codable, Hashable, Identifiable, Sendable {
    let sourceID: String
    let kind: HealthMetricKind
    let startDate: Date
    let endDate: Date
    let value: Double?
    let unit: String?
    let sourceEndpoint: OuraEndpoint
    let sourceFingerprint: String
    let attributes: [String: String]

    var id: String { "\(sourceEndpoint.rawValue):\(sourceID)" }
}

enum SyncDestination: String, Codable, Sendable {
    case local
    case healthKit
}

struct LedgerKey: Codable, Hashable, Sendable {
    let source: String
    let endpoint: OuraEndpoint
    let sourceID: String
    let sourceFingerprint: String
    let destination: SyncDestination

    var stableValue: String {
        [source, endpoint.rawValue, sourceID, sourceFingerprint, destination.rawValue]
            .joined(separator: "|")
    }
}
