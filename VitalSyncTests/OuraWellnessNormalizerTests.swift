import Foundation
import Testing
@testable import VitalSync

struct OuraWellnessNormalizerTests {
    private let normalizer = OuraWellnessNormalizer()

    @Test func syntheticSleepHRVPreservesIntervalAndRMSSDIdentity() {
        let record = OuraSleepPeriod(
            id: "synthetic-sleep-a", day: "2030-01-02",
            bedtimeStart: "2030-01-01T23:00:00-08:00",
            bedtimeEnd: "2030-01-02T07:00:00-08:00", averageHRV: 41
        )
        let metric = normalizer.normalize(record)

        #expect(metric?.kind == .rmssd)
        #expect(metric?.unit == "ms")
        #expect(metric?.attributes["startLocal"] == record.bedtimeStart)
        #expect(metric.map { $0.startDate < $0.endDate } == true)
        #expect(metric?.sourceEndpoint == .sleep)
    }

    @Test func syntheticSpO2AndTemperatureStayDayPrecision() {
        let spo2 = OuraSpO2(
            id: "synthetic-spo2-a", day: "2030-01-02",
            spo2Percentage: .init(average: 96.4)
        )
        let readiness = OuraDailyReadiness(
            id: "synthetic-readiness-a", day: "2030-01-02",
            timestamp: "2030-01-02T07:15:00-08:00", temperatureDeviation: -0.3
        )

        let oxygen = normalizer.normalize(spo2)
        let temperature = normalizer.normalize(readiness)
        #expect(oxygen?.kind == .oxygenSaturation)
        #expect(oxygen?.value == 96.4)
        #expect(oxygen?.attributes["aggregation"] == "sleepAverage")
        #expect(oxygen?.attributes["precision"] == "day")
        #expect(temperature?.kind == .bodyTemperatureDeviation)
        #expect(temperature?.value == -0.3)
        #expect(temperature?.unit == "°C from baseline")
        #expect(temperature?.attributes["precision"] == "day")
    }

    @Test func malformedOrAbsentSyntheticValuesAreNotInvented() {
        #expect(normalizer.normalize(OuraSpO2(id: "synthetic-spo2-b", day: "2030-01-02", spo2Percentage: nil)) == nil)
        #expect(normalizer.normalize(OuraDailyReadiness(id: "synthetic-ready-b", day: "2030-01-02", timestamp: nil, temperatureDeviation: nil)) == nil)
        #expect(normalizer.normalize(OuraSleepPeriod(id: "synthetic-sleep-b", day: "2030-01-02", bedtimeStart: "bad", bedtimeEnd: "2030-01-02T07:00:00Z", averageHRV: 42)) == nil)
    }
}
