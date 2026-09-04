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

    func testStartingNextArtworkAtomicallyArchivesAndOrdersPreviousArtworks() async throws {
        let store = try makeStore()
        let firstID = ArtworkID()
        _ = try await store.createCurrentArtwork(
            cycle: .milestone(.tenKilometers),
            id: firstID
        )
        let firstStart = Date(timeIntervalSince1970: 1_800_010_000)
        try await completeCurrentMilestone(in: store, at: firstStart)

        let secondID = ArtworkID()
        _ = try await store.startNextArtwork(
            cycle: .milestone(.tenKilometers),
            archivedAt: firstStart.addingTimeInterval(100),
            id: secondID
        )
        try await completeCurrentMilestone(in: store, at: firstStart.addingTimeInterval(200))

        let thirdID = ArtworkID()
        let third = try await store.startNextArtwork(
            cycle: .time(.oneMonth),
            archivedAt: firstStart.addingTimeInterval(300),
            id: thirdID
        )
        let collection = try await store.artworkCollection()
        let current = try await store.currentArtwork()

        XCTAssertEqual(current, third)
        XCTAssertEqual(collection.map(\.id), [secondID, firstID])
        XCTAssertTrue(collection.allSatisfy {
            if case .archived = $0.artwork.state { return true }
            return false
        })
    }

    func testStartingNextArtworkFromIncompleteArtworkRollsBack() async throws {
        let store = try makeStore()
        let original = try await store.createCurrentArtwork(cycle: .time(.oneMonth))

        do {
            _ = try await store.startNextArtwork(
                cycle: .milestone(.tenKilometers),
                archivedAt: Date(timeIntervalSince1970: 1_800_020_000)
            )
            XCTFail("Expected an incomplete artwork not to be replaced")
        } catch {
            XCTAssertEqual(
                error as? DomainValidationError,
                .artworkNotAcceptingActivities
            )
        }

        let current = try await store.currentArtwork()
        let collection = try await store.artworkCollection()
        XCTAssertEqual(current, original)
        XCTAssertTrue(collection.isEmpty)
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

    func testVersionOneStoreMigratesWithoutLosingCurrentArtwork() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "FurtherMigrationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appending(path: "Further.store")
        let startedAt = Date(timeIntervalSince1970: 1_799_000_000)
        var expected = Artwork(cycle: .time(.oneMonth))
        let assignment = try expected.beginActivity(
            environment: .indoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone
        )
        let record = try DomainTestSamples.record(
            assignment: assignment,
            endedAt: startedAt.addingTimeInterval(60)
        )
        try expected.include(record, finalizedAt: record.summary.endedAt)

        do {
            let schema = Schema(versionedSchema: FurtherSchemaV1.self)
            let configuration = ModelConfiguration("Further", schema: schema, url: databaseURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.insert(FurtherSchemaV1.ArtworkModel(
                id: expected.id.rawValue,
                isCurrent: true,
                snapshotData: try PersistenceCodec.encode(StoredArtworkSnapshot(expected))
            ))
            context.insert(FurtherSchemaV1.ActivityModel(
                id: record.id.rawValue,
                artworkID: record.artworkID.rawValue,
                phaseRawValue: StoredActivityPhase.finalized.rawValue,
                checkpointData: nil,
                recordData: try PersistenceCodec.encode(StoredActivityRecord(record)),
                reflectionDraftData: nil
            ))
            try context.save()
        }

        let migrated = try FurtherStore(
            modelContainer: FurtherModelContainer.persistent(at: databaseURL)
        )

        let recovery = try await migrated.recoverForBootstrap(at: record.summary.endedAt)
        let restored = recovery.currentArtwork
        let exportJobs = try await migrated.healthExportJobs(
            includeAuthorizationDenied: true
        )
        XCTAssertEqual(restored, expected)
        XCTAssertEqual(exportJobs.map(\.record), [record])
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

    func testStartingAfterTimeBoundaryPersistsCompletedArtwork() async throws {
        let store = try makeStore()
        _ = try await store.createCurrentArtwork(cycle: .time(.oneMonth))
        let startedAt = Date(timeIntervalSince1970: 1_800_450_000)
        let firstAssignment = try await startActivity(in: store, at: startedAt)
        let firstRecord = try DomainTestSamples.record(
            assignment: firstAssignment,
            endedAt: startedAt.addingTimeInterval(60)
        )
        let firstDraft = try ReflectionDraft(expression: firstRecord.expression)
        try await store.beginReflection(record: firstRecord, draft: firstDraft)
        try await store.lockExpression(firstDraft, activityID: firstAssignment.activityID)
        _ = try await store.lockReflection(
            activityID: firstAssignment.activityID,
            finalizedAt: firstRecord.summary.endedAt
        )
        guard let accumulating = try await store.currentArtwork(),
              case let .accumulating(period) = accumulating.state,
              let endsAt = period.endsAt else {
            return XCTFail("Expected an accumulating time artwork")
        }

        do {
            _ = try await startActivity(in: store, at: endsAt.addingTimeInterval(1))
            XCTFail("Expected an expired artwork to reject a new activity")
        } catch {
            XCTAssertEqual(
                error as? DomainValidationError,
                .artworkNotAcceptingActivities
            )
        }

        guard let completed = try await store.currentArtwork(),
              case .completed = completed.state else {
            return XCTFail("Expected the time boundary completion to be persisted")
        }
        XCTAssertNil(completed.pendingActivityID)
    }

    func testFinalizingAfterTimeBoundaryCompletesArtwork() async throws {
        let store = try makeStore()
        _ = try await store.createCurrentArtwork(cycle: .time(.oneMonth))
        let startedAt = Date(timeIntervalSince1970: 1_800_475_000)
        let assignment = try await startActivity(in: store, at: startedAt)
        guard let accumulating = try await store.currentArtwork(),
              case let .accumulating(period) = accumulating.state,
              let endsAt = period.endsAt else {
            return XCTFail("Expected an accumulating time artwork")
        }
        let record = try DomainTestSamples.record(
            assignment: assignment,
            endedAt: endsAt.addingTimeInterval(-1)
        )
        let draft = try ReflectionDraft(expression: record.expression)
        try await store.beginReflection(record: record, draft: draft)
        try await store.lockExpression(draft, activityID: assignment.activityID)

        _ = try await store.lockReflection(
            activityID: assignment.activityID,
            finalizedAt: endsAt.addingTimeInterval(1)
        )

        guard let completed = try await store.currentArtwork(),
              case let .completed(_, completedAt) = completed.state else {
            return XCTFail("Expected finalization to re-evaluate the time boundary")
        }
        XCTAssertEqual(completedAt, endsAt)
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

    func testModelSchemaMigratesFromVersionOneToHealthExportVersion() {
        XCTAssertEqual(FurtherSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(FurtherSchemaV2.versionIdentifier, Schema.Version(2, 0, 0))
        XCTAssertEqual(FurtherMigrationPlan.schemas.count, 2)
        XCTAssertEqual(FurtherMigrationPlan.stages.count, 1)
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

    private func completeCurrentMilestone(
        in store: FurtherStore,
        at startedAt: Date
    ) async throws {
        let assignment = try await startActivity(in: store, at: startedAt)
        let record = try DomainTestSamples.record(
            assignment: assignment,
            endedAt: startedAt.addingTimeInterval(60),
            distance: ActivityDistance(meters: 10_000, source: .manualEntry)
        )
        let draft = try ReflectionDraft(expression: record.expression)
        try await store.beginReflection(record: record, draft: draft)
        try await store.lockExpression(draft, activityID: assignment.activityID)
        _ = try await store.lockReflection(
            activityID: assignment.activityID,
            manualDistanceMeters: 10_000,
            finalizedAt: record.summary.endedAt
        )
    }
}
