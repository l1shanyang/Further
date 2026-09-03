import Foundation
import SwiftData
import XCTest
@testable import Further

final class FurtherStoreTests: XCTestCase {
    func testOnlyOneCurrentArtworkCanBeCreated() async throws {
        let store = try makeStore()
        let first = try await store.createCurrentArtwork(cycle: .milestone(.tenKilometers))

        do {
            _ = try await store.createCurrentArtwork(cycle: .time(.oneMonth))
            XCTFail("Expected the second current artwork to be rejected")
        } catch {
            XCTAssertEqual(error as? FurtherStoreError, .currentArtworkAlreadyExists)
        }
        let restored = try await store.currentArtwork()
        XCTAssertEqual(restored, first)
    }

    func testFinalRecordRoundTripsWithIndependentRouteSamples() async throws {
        let store = try makeStore()
        _ = try await store.createCurrentArtwork(cycle: .milestone(.tenKilometers))
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let assignment = try await startActivity(in: store, at: startedAt)
        let route = try RouteSample(
            measuredAt: startedAt.addingTimeInterval(30),
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
            routeSamples: [route]
        )
        let draft = try ReflectionDraft(expression: record.expression)

        try await store.beginReflection(record: record, draft: draft)
        let locked = try await store.lockReflection(
            activityID: assignment.activityID,
            finalizedAt: record.summary.endedAt
        )

        XCTAssertEqual(locked, record)
        let restored = try await store.activityRecord(id: assignment.activityID)
        XCTAssertEqual(restored, record)
        XCTAssertEqual(restored?.routeSamples, [route])
    }

    func testPersistentContainerSurvivesReopenAndBootstrapRecovery() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "FurtherStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appending(path: "Further.store")
        let startedAt = Date(timeIntervalSince1970: 1_800_100_000)
        let activityID: ActivityID

        do {
            let container = try FurtherModelContainer.persistent(at: databaseURL)
            let store = FurtherStore(modelContainer: container)
            _ = try await store.createCurrentArtwork(cycle: .time(.oneMonth))
            let assignment = try await startActivity(in: store, at: startedAt)
            activityID = assignment.activityID
            let checkpoint = try ActivityCheckpoint(
                assignment: assignment,
                capturedAt: startedAt.addingTimeInterval(90),
                activeDuration: 90,
                pausedDuration: 0,
                events: [],
                distance: nil,
                routeSamples: [],
                origin: DomainTestSamples.origin
            )
            try await store.saveCheckpoint(checkpoint)
        }

        let reopenedContainer = try FurtherModelContainer.persistent(at: databaseURL)
        let reopenedStore = FurtherStore(modelContainer: reopenedContainer)
        let recovery = try await reopenedStore.recoverForBootstrap(
            at: startedAt.addingTimeInterval(120)
        )
        let record = try await reopenedStore.activityRecord(id: activityID)

        XCTAssertEqual(recovery.interruptedActivityCount, 1)
        XCTAssertEqual(record?.lifecycle, .technicalInterruption(.appTermination))
        XCTAssertEqual(record?.summary.endedAt, startedAt.addingTimeInterval(90))
        XCTAssertEqual(record?.expression.isSilence, true)
        XCTAssertNil(recovery.currentArtwork?.pendingActivityID)
    }

    func testBootstrapLocksLastReliableReflectionDraft() async throws {
        let store = try makeStore()
        _ = try await store.createCurrentArtwork(cycle: .milestone(.tenKilometers))
        let startedAt = Date(timeIntervalSince1970: 1_800_200_000)
        let assignment = try await startActivity(in: store, at: startedAt)
        let endedAt = startedAt.addingTimeInterval(60)
        let record = try DomainTestSamples.record(assignment: assignment, endedAt: endedAt)
        try await store.beginReflection(
            record: record,
            draft: ReflectionDraft(expression: record.expression)
        )
        let feeling = RecordExpression.feeling(
            color: FeelingColor(
                identifier: "calm",
                paletteVersion: "1",
                value: try RecordColorValue(red: 0.1, green: 0.4, blue: 0.7)
            ),
            note: "steady"
        )
        try await store.saveReflectionDraft(
            ReflectionDraft(expression: feeling),
            activityID: assignment.activityID
        )

        let recovery = try await store.recoverForBootstrap(at: endedAt.addingTimeInterval(5))
        let restored = try await store.activityRecord(id: assignment.activityID)

        XCTAssertEqual(recovery.lockedReflectionCount, 1)
        XCTAssertEqual(restored?.expression, feeling)
        XCTAssertNil(recovery.currentArtwork?.pendingActivityID)
    }

    func testModelSchemaStartsAtVersionOneWithExplicitMigrationPlan() {
        XCTAssertEqual(FurtherSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(FurtherMigrationPlan.schemas.count, 1)
        XCTAssertTrue(FurtherMigrationPlan.stages.isEmpty)
    }

    private func makeStore() throws -> FurtherStore {
        FurtherStore(modelContainer: try FurtherModelContainer.inMemory())
    }

    private func startActivity(
        in store: FurtherStore,
        at date: Date
    ) async throws -> ActivityAssignment {
        try await store.startActivity(
            environment: .indoor,
            at: date,
            timeZone: DomainTestSamples.timeZone,
            origin: DomainTestSamples.origin,
            interruptionExpression: DomainTestSamples.silenceExpression()
        )
    }
}
