import XCTest
@testable import VitalSync

final class HRVTranslationEngineTests: XCTestCase {
    func testRMSSDCannotBecomeSDNN() throws {
        let result = try HRVTranslationEngine().healthKitSDNN(from: .rmssd(milliseconds: 42))
        XCTAssertNil(result)
        XCTAssertEqual(
            HealthKitMappingPolicy().mapping(for: .rmssd),
            .unsupported(reason: "Oura RMSSD is not HealthKit SDNN")
        )
    }

    func testSDNNUsesSampleStandardDeviationOfLegitimateIntervals() throws {
        let result = try XCTUnwrap(
            HRVTranslationEngine().healthKitSDNN(from: .nnIntervals(milliseconds: [800, 810, 790]))
        )
        XCTAssertEqual(result, 10, accuracy: 0.0001)
    }

    func testSDNNRejectsInvalidIntervals() {
        XCTAssertThrowsError(try SDNNCalculator().calculate(nnIntervalsMilliseconds: [800]))
        XCTAssertThrowsError(try SDNNCalculator().calculate(nnIntervalsMilliseconds: [800, 0]))
        XCTAssertThrowsError(try SDNNCalculator().calculate(nnIntervalsMilliseconds: [800, .nan]))
    }
}
