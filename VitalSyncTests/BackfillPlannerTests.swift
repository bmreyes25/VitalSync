import XCTest
@testable import VitalSync

final class BackfillPlannerTests: XCTestCase {
    func testProducesBoundedNonOverlappingWindows() throws {
        let calendar = Calendar(identifier: .iso8601)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 3, day: 5)))
        let windows = BackfillPlanner(calendar: calendar, maximumDaysPerWindow: 30).windows(from: start, through: end)

        XCTAssertEqual(windows.count, 3)
        XCTAssertEqual(windows.first?.start, start)
        XCTAssertEqual(windows.last?.end, end)
        for pair in zip(windows, windows.dropFirst()) {
            XCTAssertEqual(calendar.date(byAdding: .day, value: 1, to: pair.0.end), pair.1.start)
        }
    }
}
