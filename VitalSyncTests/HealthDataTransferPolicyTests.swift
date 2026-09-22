import XCTest
@testable import VitalSync

final class HealthDataTransferPolicyTests: XCTestCase {
    func testTransferRequiresUnlockedForegroundAndFreshConsent() {
        let policy = HealthDataTransferPolicy()
        let consent = HealthDataTransferConsent(approvedAt: .now, operationID: UUID())

        XCTAssertNoThrow(
            try policy.authorizeUserInitiatedTransfer(
                consent: consent,
                applicationState: .active,
                protectedDataAvailable: true
            )
        )
        XCTAssertThrowsError(
            try policy.authorizeUserInitiatedTransfer(
                consent: consent,
                applicationState: .background,
                protectedDataAvailable: true
            )
        ) { XCTAssertEqual($0 as? HealthDataTransferError, .backgroundTransferDisallowed) }
        XCTAssertThrowsError(
            try policy.authorizeUserInitiatedTransfer(
                consent: consent,
                applicationState: .active,
                protectedDataAvailable: false
            )
        ) { XCTAssertEqual($0 as? HealthDataTransferError, .deviceLocked) }
    }

    func testStaleOrMissingConsentIsRejected() {
        let policy = HealthDataTransferPolicy()
        let stale = HealthDataTransferConsent(approvedAt: .distantPast, operationID: UUID())

        for consent in [nil, stale] {
            XCTAssertThrowsError(
                try policy.authorizeUserInitiatedTransfer(
                    consent: consent,
                    applicationState: .active,
                    protectedDataAvailable: true
                )
            ) { XCTAssertEqual($0 as? HealthDataTransferError, .consentRequired) }
        }
    }
}
