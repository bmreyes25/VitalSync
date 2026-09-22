import Foundation
import Testing
@testable import VitalSync

struct HeartRateNormalizerTests {
    @Test func stableIdentityChangesFingerprintWhenSourceIsCorrected() throws {
        let timestamp = try #require(ISO8601DateFormatter().date(from: "2030-01-02T03:04:05Z"))
        let first = OuraHeartRate(bpm: 64, source: "awake", timestamp: timestamp, timestampUnix: 1_893_553_445_000)
        let corrected = OuraHeartRate(bpm: 65, source: "awake", timestamp: timestamp, timestampUnix: 1_893_553_445_000)

        let normalizer = HeartRateNormalizer()
        let firstMetric = try #require(normalizer.normalize(first))
        let correctedMetric = try #require(normalizer.normalize(corrected))

        #expect(firstMetric.id == correctedMetric.id)
        #expect(firstMetric.sourceFingerprint != correctedMetric.sourceFingerprint)
        #expect(firstMetric.kind == .heartRate)
        #expect(firstMetric.unit == "count/min")
        #expect(firstMetric.startDate == firstMetric.endDate)
    }

    @Test func rejectsImplausibleValue() throws {
        let timestamp = try #require(ISO8601DateFormatter().date(from: "2030-01-02T03:04:05Z"))
        let sample = OuraHeartRate(bpm: 0, source: "awake", timestamp: timestamp, timestampUnix: nil)

        #expect(HeartRateNormalizer().normalize(sample) == nil)
    }
}
