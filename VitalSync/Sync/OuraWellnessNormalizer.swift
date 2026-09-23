import CryptoKit
import Foundation

struct OuraWellnessNormalizer: Sendable {
    func normalize(_ record: OuraSpO2) -> NormalizedMetric? {
        guard let average = record.spo2Percentage?.average,
              average.isFinite, (1...100).contains(average),
              let day = dayAnchor(record.day) else { return nil }
        return metric(
            sourceID: "\(record.id):sleepAverageSpO2", kind: .oxygenSaturation,
            start: day, end: day, value: average, unit: "%",
            endpoint: .dailySpO2,
            attributes: ["day": record.day, "precision": "day", "aggregation": "sleepAverage"]
        )
    }

    func normalize(_ record: OuraSleepPeriod) -> NormalizedMetric? {
        guard let average = record.averageHRV,
              average.isFinite, (0...1_000).contains(average), average > 0,
              let start = timestamp(record.bedtimeStart),
              let end = timestamp(record.bedtimeEnd), end > start else { return nil }
        return metric(
            sourceID: "\(record.id):averageRMSSD", kind: .rmssd,
            start: start, end: end, value: average, unit: "ms",
            endpoint: .sleep,
            attributes: [
                "day": record.day,
                "aggregation": "sleepAverage",
                "startLocal": record.bedtimeStart,
                "endLocal": record.bedtimeEnd
            ]
        )
    }

    func normalize(_ record: OuraDailyReadiness) -> NormalizedMetric? {
        guard let deviation = record.temperatureDeviation,
              deviation.isFinite, (-20...20).contains(deviation),
              let day = dayAnchor(record.day) else { return nil }
        var attributes = [
            "day": record.day,
            "precision": "day",
            "aggregation": "sleepAverageDeviationFromPersonalBaseline"
        ]
        if let timestamp = record.timestamp { attributes["sourceTimestamp"] = timestamp }
        return metric(
            sourceID: "\(record.id):temperatureDeviation", kind: .bodyTemperatureDeviation,
            start: day, end: day, value: deviation, unit: "°C from baseline",
            endpoint: .dailyReadiness, attributes: attributes
        )
    }

    private func metric(
        sourceID: String, kind: HealthMetricKind, start: Date, end: Date,
        value: Double, unit: String, endpoint: OuraEndpoint,
        attributes: [String: String]
    ) -> NormalizedMetric {
        let revision = "\(sourceID)|\(kind.rawValue)|\(start.timeIntervalSince1970)|\(end.timeIntervalSince1970)|\(value)|\(unit)"
        let fingerprint = SHA256.hash(data: Data(revision.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return NormalizedMetric(
            sourceID: sourceID, kind: kind, startDate: start, endDate: end,
            value: value, unit: unit, sourceEndpoint: endpoint,
            sourceFingerprint: fingerprint, attributes: attributes
        )
    }

    private func dayAnchor(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let midnight = formatter.date(from: value), formatter.string(from: midnight) == value else { return nil }
        return midnight.addingTimeInterval(12 * 60 * 60)
    }

    private func timestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
