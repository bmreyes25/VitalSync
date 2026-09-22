import CryptoKit
import Foundation

struct HeartRateNormalizer: Sendable {
    func normalize(_ sample: OuraHeartRate) -> NormalizedMetric? {
        guard (20...250).contains(sample.bpm) else { return nil }

        let timestampMillis = sample.timestampUnix ?? Int64((sample.timestamp.timeIntervalSince1970 * 1_000).rounded())
        let source = sample.source ?? "unknown"
        let sourceID = "\(timestampMillis):\(source)"
        let fingerprintSource = "\(sourceID):\(sample.bpm)"
        let digest = SHA256.hash(data: Data(fingerprintSource.utf8))
        let fingerprint = digest.map { String(format: "%02x", $0) }.joined()

        return NormalizedMetric(
            sourceID: sourceID,
            kind: .heartRate,
            startDate: sample.timestamp,
            endDate: sample.timestamp,
            value: Double(sample.bpm),
            unit: "count/min",
            sourceEndpoint: .heartrate,
            sourceFingerprint: fingerprint,
            attributes: ["source": source]
        )
    }
}
