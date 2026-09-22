import Foundation
import UIKit

enum HealthDataTransferError: Error, Equatable {
    case deviceLocked
    case consentRequired
    case backgroundTransferDisallowed
    case invalidFileType
    case fileTooLarge
    case invalidEnvelope
}

struct HealthDataTransferConsent: Sendable {
    let approvedAt: Date
    let operationID: UUID
}

struct HealthDataTransferPolicy: Sendable {
    static let fileExtension = "vitalsync"
    static let maximumImportSize = 50 * 1_024 * 1_024

    func authorizeUserInitiatedTransfer(
        consent: HealthDataTransferConsent?,
        applicationState: UIApplication.State,
        protectedDataAvailable: Bool
    ) throws {
        guard protectedDataAvailable else {
            throw HealthDataTransferError.deviceLocked
        }
        guard applicationState == .active else {
            throw HealthDataTransferError.backgroundTransferDisallowed
        }
        guard let consent, Date().timeIntervalSince(consent.approvedAt) < 60 else {
            throw HealthDataTransferError.consentRequired
        }
    }

    func validateImport(at url: URL) throws {
        guard url.pathExtension.lowercased() == Self.fileExtension else {
            throw HealthDataTransferError.invalidFileType
        }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else { throw HealthDataTransferError.invalidEnvelope }
        guard (values.fileSize ?? 0) <= Self.maximumImportSize else {
            throw HealthDataTransferError.fileTooLarge
        }
    }

    func protectExport(at url: URL) throws {
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var protectedURL = url
        try protectedURL.setResourceValues(values)
    }
}
