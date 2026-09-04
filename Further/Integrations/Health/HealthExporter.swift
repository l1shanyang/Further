import Foundation
import OSLog

actor HealthExporter {
    private let store: FurtherStore
    private let writer: any HealthWriter
    private let logger = Logger(
        subsystem: "com.lishanyang.Further",
        category: "HealthExport"
    )

    init(store: FurtherStore, writer: any HealthWriter) {
        self.store = store
        self.writer = writer
    }

    func authorizationState() async -> HealthAuthorizationState {
        await writer.authorizationState()
    }

    func hasPendingExports() async -> Bool {
        do {
            return try await !store.healthExportJobs(
                includeAuthorizationDenied: true
            ).isEmpty
        } catch {
            logger.error("Unable to load pending Health exports: \(String(describing: error), privacy: .private)")
            return false
        }
    }

    func exportPending(allowAuthorizationRequest: Bool) async {
        let jobs: [HealthExportJob]
        do {
            jobs = try await store.healthExportJobs(
                includeAuthorizationDenied: allowAuthorizationRequest
            )
        } catch {
            logger.error("Unable to load pending Health exports: \(String(describing: error), privacy: .private)")
            return
        }
        guard !jobs.isEmpty else { return }

        var authorization = await writer.authorizationState()
        if authorization == .notDetermined, allowAuthorizationRequest {
            authorization = await writer.requestAuthorization()
        }

        guard authorization == .authorized else {
            if authorization == .denied {
                for job in jobs {
                    do {
                        try await store.markHealthExportAuthorizationDenied(
                            activityID: job.record.id
                        )
                    } catch {
                        logger.error("Unable to persist denied Health export state: \(String(describing: error), privacy: .private)")
                    }
                }
            }
            return
        }

        for job in jobs {
            do {
                let receipt = try await writer.write(job.record)
                try await store.markHealthExported(
                    activityID: job.record.id,
                    receipt: receipt
                )
            } catch {
                logger.error("Health export will be retried: \(String(describing: error), privacy: .private)")
                do {
                    try await store.markHealthExportRetryPending(
                        activityID: job.record.id
                    )
                } catch {
                    logger.error("Unable to persist Health retry state: \(String(describing: error), privacy: .private)")
                }
            }
        }
    }
}
