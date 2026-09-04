import Foundation
import XCTest
@testable import Further

final class HealthExporterTests: XCTestCase {
    func testFinalizedRecordIsQueuedAndExportsAfterAuthorization() async throws {
        let store = try makeStore()
        let record = try await finalizedRecord(in: store)
        let writer = TestHealthWriter(
            authorization: .notDetermined,
            requestResult: .authorized
        )
        let exporter = HealthExporter(store: store, writer: writer)

        await exporter.exportPending(allowAuthorizationRequest: false)
        let initialRequestCount = await writer.requestCount()
        let initialWriteCount = await writer.writeCount()
        XCTAssertEqual(initialRequestCount, 0)
        XCTAssertEqual(initialWriteCount, 0)

        await exporter.exportPending(allowAuthorizationRequest: true)

        let snapshot = try await store.healthExportSnapshot(activityID: record.id)
        XCTAssertEqual(snapshot?.state, .exported)
        XCTAssertNotNil(snapshot?.workoutUUID)
        XCTAssertNotNil(snapshot?.routeUUID)
        XCTAssertEqual(snapshot?.attemptCount, 1)
        let requestCount = await writer.requestCount()
        let writtenRecords = await writer.writtenRecords()
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(writtenRecords, [record])
    }

    func testDeniedAuthorizationDoesNotPromptAgainOrChangeLocalRecord() async throws {
        let store = try makeStore()
        let record = try await finalizedRecord(in: store)
        let writer = TestHealthWriter(
            authorization: .notDetermined,
            requestResult: .denied
        )
        let exporter = HealthExporter(store: store, writer: writer)

        await exporter.exportPending(allowAuthorizationRequest: true)
        await exporter.exportPending(allowAuthorizationRequest: true)

        let snapshot = try await store.healthExportSnapshot(activityID: record.id)
        XCTAssertEqual(snapshot?.state, .authorizationDenied)
        let requestCount = await writer.requestCount()
        let writeCount = await writer.writeCount()
        let storedRecord = try await store.activityRecord(id: record.id)
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(writeCount, 0)
        XCTAssertEqual(storedRecord, record)
    }

    func testTemporaryFailureRetriesWithOneIdempotentWorkoutIdentity() async throws {
        let store = try makeStore()
        let record = try await finalizedRecord(in: store)
        let writer = TestHealthWriter(
            authorization: .authorized,
            requestResult: .authorized,
            failuresBeforeSuccess: 1
        )
        let exporter = HealthExporter(store: store, writer: writer)

        await exporter.exportPending(allowAuthorizationRequest: false)
        var snapshot = try await store.healthExportSnapshot(activityID: record.id)
        XCTAssertEqual(snapshot?.state, .retryPending)

        await exporter.exportPending(allowAuthorizationRequest: false)
        snapshot = try await store.healthExportSnapshot(activityID: record.id)

        XCTAssertEqual(snapshot?.state, .exported)
        XCTAssertEqual(snapshot?.attemptCount, 2)
        let uniqueWorkoutCount = await writer.uniqueWorkoutCount()
        let writeCount = await writer.writeCount()
        XCTAssertEqual(uniqueWorkoutCount, 1)
        XCTAssertEqual(writeCount, 2)
    }

    func testTechnicalInterruptionExportsSameReliableRecordShape() async throws {
        let store = try makeStore()
        _ = try await store.createCurrentArtwork(cycle: .time(.oneMonth))
        let startedAt = Date(timeIntervalSince1970: 1_820_000_000)
        let assignment = try await store.startActivity(
            environment: .outdoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone,
            origin: DomainTestSamples.origin,
            interruptionExpression: DomainTestSamples.silenceExpression()
        )
        let recovery = try await store.recoverForBootstrap(
            at: startedAt.addingTimeInterval(90),
            interruptionReason: .appTermination
        )
        XCTAssertEqual(recovery.interruptedActivityCount, 1)
        let writer = TestHealthWriter(
            authorization: .authorized,
            requestResult: .authorized
        )
        let exporter = HealthExporter(store: store, writer: writer)

        await exporter.exportPending(allowAuthorizationRequest: false)

        let written = await writer.writtenRecords()
        XCTAssertEqual(written.count, 1)
        XCTAssertEqual(written.first?.id, assignment.activityID)
        XCTAssertFalse(written.first?.lifecycle.isNormalEnd ?? true)
    }

    private func makeStore() throws -> FurtherStore {
        FurtherStore(modelContainer: try FurtherModelContainer.inMemory())
    }

    private func finalizedRecord(in store: FurtherStore) async throws -> SharedActivityRecordV1 {
        _ = try await store.createCurrentArtwork(cycle: .time(.oneMonth))
        let startedAt = Date(timeIntervalSince1970: 1_819_900_000)
        let assignment = try await store.startActivity(
            environment: .outdoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone,
            origin: DomainTestSamples.origin,
            interruptionExpression: DomainTestSamples.silenceExpression()
        )
        let route = try RouteSample(
            measuredAt: startedAt.addingTimeInterval(10),
            latitude: 31.2304,
            longitude: 121.4737,
            altitudeMeters: 4,
            horizontalAccuracyMeters: 5,
            verticalAccuracyMeters: 7,
            quality: .accepted,
            qualityRuleVersion: "1"
        )
        let record = try DomainTestSamples.record(
            assignment: assignment,
            endedAt: startedAt.addingTimeInterval(60),
            distance: ActivityDistance(
                meters: 250,
                source: .locationDerived(ruleVersion: "1")
            ),
            pausedDuration: 10,
            events: [
                ActivityEvent(kind: .paused, occurredAt: startedAt.addingTimeInterval(20)),
                ActivityEvent(kind: .resumed, occurredAt: startedAt.addingTimeInterval(30)),
            ],
            routeSamples: [route]
        )
        let draft = try ReflectionDraft(expression: record.expression)
        try await store.beginReflection(record: record, draft: draft)
        try await store.lockExpression(draft, activityID: assignment.activityID)
        return try await store.lockReflection(
            activityID: assignment.activityID,
            finalizedAt: record.summary.endedAt
        )
    }
}

private actor TestHealthWriter: HealthWriter {
    private var authorization: HealthAuthorizationState
    private let requestResult: HealthAuthorizationState
    private var failuresBeforeSuccess: Int
    private var requests = 0
    private var records: [SharedActivityRecordV1] = []
    private var workoutIDs: [ActivityID: UUID] = [:]
    private var routeIDs: [ActivityID: UUID] = [:]

    init(
        authorization: HealthAuthorizationState,
        requestResult: HealthAuthorizationState,
        failuresBeforeSuccess: Int = 0
    ) {
        self.authorization = authorization
        self.requestResult = requestResult
        self.failuresBeforeSuccess = failuresBeforeSuccess
    }

    func authorizationState() -> HealthAuthorizationState { authorization }

    func requestAuthorization() -> HealthAuthorizationState {
        requests += 1
        authorization = requestResult
        return authorization
    }

    func write(_ record: SharedActivityRecordV1) throws -> HealthWriteReceipt {
        records.append(record)
        let workoutID = workoutIDs[record.id] ?? UUID()
        workoutIDs[record.id] = workoutID
        let routeID: UUID? = if record.routeSamples.isEmpty {
            nil
        } else {
            routeIDs[record.id] ?? UUID()
        }
        if let routeID {
            routeIDs[record.id] = routeID
        }
        if failuresBeforeSuccess > 0 {
            failuresBeforeSuccess -= 1
            throw TestHealthWriterFailure.temporary
        }
        return HealthWriteReceipt(workoutUUID: workoutID, routeUUID: routeID)
    }

    func requestCount() -> Int { requests }
    func writeCount() -> Int { records.count }
    func writtenRecords() -> [SharedActivityRecordV1] { records }
    func uniqueWorkoutCount() -> Int { Set(workoutIDs.values).count }
}

private enum TestHealthWriterFailure: Error {
    case temporary
}
