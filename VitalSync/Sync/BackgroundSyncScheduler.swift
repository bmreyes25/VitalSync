import BackgroundTasks
import Foundation

struct BackgroundSyncScheduler: Sendable {
    static let taskIdentifier = "com.bmreyes25.VitalSync.refresh"

    func schedule(after earliest: TimeInterval = 60 * 60 * 6) async throws {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date().addingTimeInterval(earliest)
        try await BGTaskScheduler.shared.submitTaskRequest(request)
    }
}
