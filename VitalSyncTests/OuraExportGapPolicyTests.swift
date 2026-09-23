import Testing
@testable import VitalSync

struct OuraExportGapPolicyTests {
    private let policy = OuraExportGapPolicy()

    @Test func builtInOuraHealthExportsAreNeverEligible() {
        #expect(policy.eligibility(for: .heartRate) == .alreadyAvailableFromOura)
        #expect(policy.eligibility(for: .sleep) == .alreadyAvailableFromOura)
        #expect(policy.eligibility(for: .steps) == .alreadyAvailableFromOura)
    }

    @Test func apparentGapsStayBlockedWithoutSourceSemantics() {
        guard case .needsSemanticReview = policy.eligibility(for: .oxygenSaturation) else {
            Issue.record("Daily SpO2 must not be exported using an invented time interval")
            return
        }
        guard case .needsSemanticReview = policy.eligibility(for: .vo2Max) else {
            Issue.record("VO2 max must not be exported with an invented test method")
            return
        }
        #expect(policy.eligibility(for: .rmssd) == .noHealthKitEquivalent)
    }

    @Test func noCurrentMetricIsAccidentallyEligible() {
        #expect(HealthMetricKind.allCases.allSatisfy { policy.eligibility(for: $0) != .eligible })
    }
}
