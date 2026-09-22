import BackgroundTasks
import Foundation

struct BackgroundSyncScheduler: Sendable {
    static let taskIdentifier = "com.example.VitalSync.refresh"

    func schedule(after earliest: TimeInterval = 60 * 60 * 6) throws {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date().addingTimeInterval(earliest)
        try BGTaskScheduler.shared.submit(request)
    }
}
