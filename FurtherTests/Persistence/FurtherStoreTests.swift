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
        try await store.lockExpression(draft, activityID: assignment.activityID)
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

    func testRecordIndexIncludesTechnicalInterruptionsAndExcludesUnfinishedActivities() async throws {
        let store = try makeStore()
        _ = try await store.createCurrentArtwork(cycle: .time(.oneMonth))
        let startedAt = Date(timeIntervalSince1970: 1_800_150_000)
        let interrupted = try await startActivity(in: store, at: startedAt)

        _ = try await store.recoverForBootstrap(at: startedAt.addingTimeInterval(30))
        _ = try await startActivity(in: store, at: startedAt.addingTimeInterval(60))

        let records = try await store.allRecordIndexEntries()

        XCTAssertEqual(records.map(\.id), [interrupted.activityID])
        XCTAssertEqual(
            records.first?.lifecycle,
            .technicalInterruption(.appTermination)
        )
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

    func testManualDistanceAndExpressionLockAtomicallyEnterArtwork() async throws {
        let store = try makeStore()
        _ = try await store.createCurrentArtwork(cycle: .milestone(.tenKilometers))
        let startedAt = Date(timeIntervalSince1970: 1_800_300_000)
        let assignment = try await startActivity(in: store, at: startedAt)
        let endedAt = startedAt.addingTimeInterval(60)
        let record = try DomainTestSamples.record(assignment: assignment, endedAt: endedAt)
        try await store.beginReflection(
            record: record,
            draft: ReflectionDraft(expression: record.expression)
        )
        let feeling = RecordExpression.feeling(
            color: FeelingColorOption.all[2].color,
            note: "finished strong"
        )
        let feelingDraft = try ReflectionDraft(expression: feeling)
        try await store.saveReflectionDraft(
            feelingDraft,
            activityID: assignment.activityID
        )
        try await store.lockExpression(feelingDraft, activityID: assignment.activityID)

        do {
            try await store.saveReflectionDraft(
                ReflectionDraft(expression: try DomainTestSamples.silenceExpression()),
                activityID: assignment.activityID
            )
            XCTFail("Expected expression edits to be rejected immediately after locking")
        } catch {
            XCTAssertEqual(error as? FurtherStoreError, .invalidActivityPhase)
        }

        let locked = try await store.lockReflection(
            activityID: assignment.activityID,
            manualDistanceMeters: 10_000,
            finalizedAt: endedAt
        )

        XCTAssertEqual(locked.expression, feeling)
        XCTAssertEqual(locked.summary.distance?.meters, 10_000)
        XCTAssertEqual(locked.summary.distance?.source, .manualEntry)
        guard let completedArtwork = try await store.currentArtwork(),
              case .completed = completedArtwork.state else {
            return XCTFail("Expected the manual distance to complete the milestone artwork")
        }

    }

    func testSkippingIndoorDistanceKeepsDistanceUnknown() async throws {
        let store = try makeStore()
        _ = try await store.createCurrentArtwork(cycle: .milestone(.tenKilometers))
        let startedAt = Date(timeIntervalSince1970: 1_800_400_000)
        let assignment = try await startActivity(in: store, at: startedAt)
        let endedAt = startedAt.addingTimeInterval(60)
        let record = try DomainTestSamples.record(assignment: assignment, endedAt: endedAt)
        try await store.beginReflection(
            record: record,
            draft: ReflectionDraft(expression: record.expression)
        )
        try await store.lockExpression(
            ReflectionDraft(expression: record.expression),
            activityID: assignment.activityID
        )

        let locked = try await store.lockReflection(
            activityID: assignment.activityID,
            finalizedAt: endedAt
        )

        XCTAssertNil(locked.summary.distance)
        guard let accumulatingArtwork = try await store.currentArtwork(),
              case .accumulating = accumulatingArtwork.state else {
            return XCTFail("Expected an unknown distance not to complete the milestone")
        }
    }

    func testLastSavedDraftCanReturnFromFeelingToSilence() async throws {
        let store = try makeStore()
        _ = try await store.createCurrentArtwork(cycle: .time(.oneMonth))
        let startedAt = Date(timeIntervalSince1970: 1_800_500_000)
        let assignment = try await startActivity(in: store, at: startedAt)
        let endedAt = startedAt.addingTimeInterval(60)
        let record = try DomainTestSamples.record(assignment: assignment, endedAt: endedAt)
        try await store.beginReflection(
            record: record,
            draft: ReflectionDraft(expression: record.expression)
        )
        try await store.saveReflectionDraft(
            ReflectionDraft(expression: .feeling(
                color: FeelingColorOption.all[0].color,
                note: "first choice"
            )),
            activityID: assignment.activityID
        )
        let silence = try DomainTestSamples.silenceExpression(note: "quiet instead")
        try await store.saveReflectionDraft(
            ReflectionDraft(expression: silence),
            activityID: assignment.activityID
        )
        try await store.lockExpression(
            ReflectionDraft(expression: silence),
            activityID: assignment.activityID
        )

        let locked = try await store.lockReflection(
            activityID: assignment.activityID,
            finalizedAt: endedAt
        )

        XCTAssertEqual(locked.expression, silence)
    }

    func testBootstrapFinalizesLockedExpressionWithoutIndoorDistance() async throws {
        let store = try makeStore()
        _ = try await store.createCurrentArtwork(cycle: .milestone(.tenKilometers))
        let startedAt = Date(timeIntervalSince1970: 1_800_600_000)
        let assignment = try await startActivity(in: store, at: startedAt)
        let endedAt = startedAt.addingTimeInterval(60)
        let record = try DomainTestSamples.record(assignment: assignment, endedAt: endedAt)
        let expression = RecordExpression.feeling(
            color: FeelingColorOption.all[3].color,
            note: "locked before distance"
        )
        try await store.beginReflection(
            record: record,
            draft: ReflectionDraft(expression: record.expression)
        )
        try await store.lockExpression(
            ReflectionDraft(expression: expression),
            activityID: assignment.activityID
        )

        let recovery = try await store.recoverForBootstrap(at: endedAt.addingTimeInterval(5))
        let recovered = try await store.activityRecord(id: assignment.activityID)

        XCTAssertEqual(recovery.lockedReflectionCount, 1)
        XCTAssertEqual(recovered?.expression, expression)
        XCTAssertNil(recovered?.summary.distance)
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
