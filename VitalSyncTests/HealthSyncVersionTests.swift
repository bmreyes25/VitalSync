import Foundation
import Testing
@testable import VitalSync

struct HealthSyncVersionTests {
    @Test func versionsIncreaseForRapidWritesAndClockRollback() {
        var sequencer = HealthSyncVersionSequencer()
        let firstTime = Date(timeIntervalSince1970: 1_893_553_445)

        let first = sequencer.next(at: firstTime)
        let sameMillisecond = sequencer.next(at: firstTime)
        let earlierClock = sequencer.next(at: firstTime.addingTimeInterval(-60))

        #expect(first == 1_893_553_445_000)
        #expect(sameMillisecond == first + 1)
        #expect(earlierClock == sameMillisecond + 1)
    }
}
