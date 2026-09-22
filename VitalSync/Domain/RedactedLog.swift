import Foundation
import OSLog

struct RedactedLog: Sendable {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "VitalSync", category: "sync")

    func event(_ name: StaticString, code: String? = nil) {
        if let code {
            logger.info("\(name, privacy: .public) code=\(code, privacy: .public)")
        } else {
            logger.info("\(name, privacy: .public)")
        }
    }

    func failure(_ name: StaticString, errorCode: String) {
        logger.error("\(name, privacy: .public) code=\(errorCode, privacy: .public)")
    }
}
