import Foundation
import SwiftData

enum FurtherStoreError: Error, Equatable {
    case noCurrentArtwork
    case currentArtworkAlreadyExists
    case multipleCurrentArtworks
    case activityNotFound
    case invalidActivityPhase
    case storedIdentityMismatch
}

struct BootstrapRecovery: Equatable, Sendable {
    let currentArtwork: Artwork?
    let interruptedActivityCount: Int
    let lockedReflectionCount: Int
}

@ModelActor
actor FurtherStore {
    func createCurrentArtwork(
        cycle: ArtworkCycle,
        id: ArtworkID = ArtworkID()
    ) throws -> Artwork {
        try transaction {
            guard try currentArtworkModels().isEmpty else {
                throw FurtherStoreError.currentArtworkAlreadyExists
            }

            let artwork = Artwork(id: id, cycle: cycle)
            let model = FurtherSchemaV1.ArtworkModel(
                id: id.rawValue,
                isCurrent: true,
                snapshotData: try PersistenceCodec.encode(StoredArtworkSnapshot(artwork))
            )
            modelContext.insert(model)
            return artwork
        }
    }

    func currentArtwork() throws -> Artwork? {
        let models = try currentArtworkModels()
        guard models.count <= 1 else {
            throw FurtherStoreError.multipleCurrentArtworks
        }
        guard let model = models.first else { return nil }
        return try artwork(from: model)
    }

    func records(for artworkID: ArtworkID) throws -> [SharedActivityRecordV1] {
        let artworkModel = try requiredArtworkModel(id: artworkID)
        let artwork = try artwork(from: artworkModel)
        let modelsByID = Dictionary(
            uniqueKeysWithValues: try activityModels().map { ($0.id, $0) }
        )

        return try artwork.activityIDs.compactMap { activityID in
            guard let model = modelsByID[activityID.rawValue],
                  try phase(of: model) == .finalized else {
                return nil
            }
            return try record(from: model)
        }
    }

    func evaluateCurrentArtwork(at date: Date) throws -> Artwork? {
        try transaction {
            guard let model = try singleCurrentArtworkModel() else { return nil }
            var artwork = try artwork(from: model)
            artwork.evaluate(at: date)
            model.snapshotData = try PersistenceCodec.encode(StoredArtworkSnapshot(artwork))
            return artwork
        }
    }

    func startActivity(
        id activityID: ActivityID = ActivityID(),
        environment: RunningEnvironment,
        at startedAt: Date,
        timeZone: TimeZone,
        origin: ActivityOrigin,
        interruptionExpression: RecordExpression
    ) throws -> ActivityAssignment {
        try transaction {
            guard interruptionExpression.isSilence else {
                throw DomainValidationError.invalidExpressionForLifecycle
            }
            let artworkModel = try requiredCurrentArtworkModel()
            var artwork = try artwork(from: artworkModel)
            let assignment = try artwork.beginActivity(
                id: activityID,
                environment: environment,
                at: startedAt,
                timeZone: timeZone
            )
            let checkpoint = try ActivityCheckpoint(
                assignment: assignment,
                capturedAt: startedAt,
                activeDuration: 0,
                pausedDuration: 0,
                events: [],
                distance: nil,
                routeSamples: [],
                origin: origin
            )
            let draft = try ReflectionDraft(expression: interruptionExpression)

            artworkModel.snapshotData = try PersistenceCodec.encode(StoredArtworkSnapshot(artwork))
            modelContext.insert(FurtherSchemaV1.ActivityModel(
                id: activityID.rawValue,
                artworkID: artwork.id.rawValue,
                phaseRawValue: StoredActivityPhase.inProgress.rawValue,
                checkpointData: try PersistenceCodec.encode(StoredCheckpoint(checkpoint)),
                recordData: nil,
                reflectionDraftData: try PersistenceCodec.encode(draft)
            ))
            return assignment
        }
    }

    func saveCheckpoint(_ checkpoint: ActivityCheckpoint) throws {
        try transaction {
            try checkpoint.validate()
            let activityModel = try requiredActivityModel(id: checkpoint.assignment.activityID)
            guard try phase(of: activityModel) == .inProgress else {
                throw FurtherStoreError.invalidActivityPhase
            }
            guard activityModel.artworkID == checkpoint.assignment.artworkID.rawValue else {
                throw FurtherStoreError.storedIdentityMismatch
            }
            let previous = try self.checkpoint(from: activityModel)
            guard checkpoint.assignment == previous.assignment,
                  checkpoint.origin == previous.origin,
                  checkpoint.capturedAt >= previous.capturedAt else {
                throw FurtherStoreError.storedIdentityMismatch
            }

            activityModel.checkpointData = try PersistenceCodec.encode(StoredCheckpoint(checkpoint))
            try replaceRouteSamples(
                checkpoint.routeSamples,
                activityID: checkpoint.assignment.activityID
            )
        }
    }

    func beginReflection(
        record: SharedActivityRecordV1,
        draft: ReflectionDraft
    ) throws {
        try transaction {
            try record.validate()
            guard record.lifecycle.isNormalEnd else {
                throw FurtherStoreError.invalidActivityPhase
            }
            let activityModel = try requiredActivityModel(id: record.id)
            guard try phase(of: activityModel) == .inProgress,
                  activityModel.artworkID == record.artworkID.rawValue else {
                throw FurtherStoreError.invalidActivityPhase
            }
            let checkpoint = try self.checkpoint(from: activityModel)
            guard record.id == checkpoint.assignment.activityID,
                  record.artworkID == checkpoint.assignment.artworkID,
                  record.environment == checkpoint.assignment.environment,
                  record.origin == checkpoint.origin,
                  record.summary.startedAt == checkpoint.assignment.startedAt,
                  record.summary.startTimeZoneIdentifier
                    == checkpoint.assignment.startTimeZoneIdentifier,
                  record.summary.endedAt >= checkpoint.capturedAt else {
                throw FurtherStoreError.storedIdentityMismatch
            }

            activityModel.phaseRawValue = StoredActivityPhase.reflectionDraft.rawValue
            activityModel.recordData = try PersistenceCodec.encode(StoredActivityRecord(record))
            activityModel.reflectionDraftData = try PersistenceCodec.encode(draft)
            try replaceRouteSamples(record.routeSamples, activityID: record.id)
        }
    }

    func endActivity(
        checkpoint: ActivityCheckpoint,
        record: SharedActivityRecordV1,
        draft: ReflectionDraft
    ) throws {
        try transaction {
            try checkpoint.validate()
            try record.validate()
            guard record.lifecycle.isNormalEnd else {
                throw FurtherStoreError.invalidActivityPhase
            }

            let activityModel = try requiredActivityModel(id: record.id)
            guard try phase(of: activityModel) == .inProgress,
                  activityModel.artworkID == record.artworkID.rawValue else {
                throw FurtherStoreError.invalidActivityPhase
            }
            let previous = try self.checkpoint(from: activityModel)
            guard checkpoint.assignment == previous.assignment,
                  checkpoint.origin == previous.origin,
                  checkpoint.capturedAt >= previous.capturedAt,
                  record.id == checkpoint.assignment.activityID,
                  record.artworkID == checkpoint.assignment.artworkID,
                  record.environment == checkpoint.assignment.environment,
                  record.origin == checkpoint.origin,
                  record.summary.startedAt == checkpoint.assignment.startedAt,
                  record.summary.startTimeZoneIdentifier
                    == checkpoint.assignment.startTimeZoneIdentifier,
                  record.summary.endedAt == checkpoint.capturedAt,
                  record.summary.activeDuration == checkpoint.activeDuration,
                  record.summary.pausedDuration == checkpoint.pausedDuration,
                  record.summary.distance == checkpoint.distance,
                  record.events == checkpoint.events,
                  record.routeSamples == checkpoint.routeSamples,
                  record.expression == draft.expression else {
                throw FurtherStoreError.storedIdentityMismatch
            }

            activityModel.phaseRawValue = StoredActivityPhase.reflectionDraft.rawValue
            activityModel.checkpointData = try PersistenceCodec.encode(StoredCheckpoint(checkpoint))
            activityModel.recordData = try PersistenceCodec.encode(StoredActivityRecord(record))
            activityModel.reflectionDraftData = try PersistenceCodec.encode(draft)
            try replaceRouteSamples(record.routeSamples, activityID: record.id)
        }
    }

    func saveReflectionDraft(
        _ draft: ReflectionDraft,
        activityID: ActivityID
    ) throws {
        try transaction {
            let activityModel = try requiredActivityModel(id: activityID)
            guard try phase(of: activityModel) == .reflectionDraft else {
                throw FurtherStoreError.invalidActivityPhase
            }
            activityModel.reflectionDraftData = try PersistenceCodec.encode(draft)
        }
    }

    @discardableResult
    func lockReflection(
        activityID: ActivityID,
        finalizedAt: Date
    ) throws -> SharedActivityRecordV1 {
        try transaction {
            let activityModel = try requiredActivityModel(id: activityID)
            guard try phase(of: activityModel) == .reflectionDraft else {
                throw FurtherStoreError.invalidActivityPhase
            }
            return try lockReflection(activityModel, finalizedAt: finalizedAt)
        }
    }

    func activityRecord(id: ActivityID) throws -> SharedActivityRecordV1? {
        guard let model = try activityModels().first(where: { $0.id == id.rawValue }),
              try phase(of: model) == .finalized else {
            return nil
        }
        return try record(from: model)
    }

    func recoverForBootstrap(
        at date: Date,
        interruptionReason: TechnicalInterruptionReason = .appTermination
    ) throws -> BootstrapRecovery {
        try transaction {
            var interruptedCount = 0
            var lockedCount = 0

            for activityModel in try activityModels() {
                switch try phase(of: activityModel) {
                case .inProgress:
                    let checkpoint = try checkpoint(from: activityModel)
                    let draft = try reflectionDraft(from: activityModel)
                    let interruptedRecord = try checkpoint.interruptedRecord(
                        reason: interruptionReason,
                        expression: draft.expression
                    )
                    try finalize(
                        interruptedRecord,
                        activityModel: activityModel,
                        finalizedAt: date
                    )
                    interruptedCount += 1
                case .reflectionDraft:
                    _ = try lockReflection(activityModel, finalizedAt: date)
                    lockedCount += 1
                case .finalized:
                    continue
                }
            }

            if let currentModel = try singleCurrentArtworkModel() {
                var current = try artwork(from: currentModel)
                current.evaluate(at: date)
                currentModel.snapshotData = try PersistenceCodec.encode(StoredArtworkSnapshot(current))
            }

            return BootstrapRecovery(
                currentArtwork: try currentArtwork(),
                interruptedActivityCount: interruptedCount,
                lockedReflectionCount: lockedCount
            )
        }
    }

    private func lockReflection(
        _ activityModel: FurtherSchemaV1.ActivityModel,
        finalizedAt: Date
    ) throws -> SharedActivityRecordV1 {
        let draft = try reflectionDraft(from: activityModel)
        let stored = try requiredStoredRecord(from: activityModel)
        let routes = try routeSamples(activityID: ActivityID(rawValue: activityModel.id))
        let record = try stored.domainValue(
            routeSamples: routes,
            expression: draft.expression
        )
        try finalize(record, activityModel: activityModel, finalizedAt: finalizedAt)
        return record
    }

    private func finalize(
        _ record: SharedActivityRecordV1,
        activityModel: FurtherSchemaV1.ActivityModel,
        finalizedAt: Date
    ) throws {
        guard activityModel.id == record.id.rawValue,
              activityModel.artworkID == record.artworkID.rawValue else {
            throw FurtherStoreError.storedIdentityMismatch
        }
        let artworkModel = try requiredArtworkModel(id: record.artworkID)
        var artwork = try artwork(from: artworkModel)
        try artwork.include(record, finalizedAt: finalizedAt)

        artworkModel.snapshotData = try PersistenceCodec.encode(StoredArtworkSnapshot(artwork))
        activityModel.phaseRawValue = StoredActivityPhase.finalized.rawValue
        activityModel.checkpointData = nil
        activityModel.recordData = try PersistenceCodec.encode(StoredActivityRecord(record))
        activityModel.reflectionDraftData = nil
        try replaceRouteSamples(record.routeSamples, activityID: record.id)
    }

    private func transaction<T>(_ operation: () throws -> T) throws -> T {
        do {
            let value = try operation()
            try modelContext.save()
            return value
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func currentArtworkModels() throws -> [FurtherSchemaV1.ArtworkModel] {
        try artworkModels().filter(\.isCurrent)
    }

    private func singleCurrentArtworkModel() throws -> FurtherSchemaV1.ArtworkModel? {
        let models = try currentArtworkModels()
        guard models.count <= 1 else {
            throw FurtherStoreError.multipleCurrentArtworks
        }
        return models.first
    }

    private func requiredCurrentArtworkModel() throws -> FurtherSchemaV1.ArtworkModel {
        guard let model = try singleCurrentArtworkModel() else {
            throw FurtherStoreError.noCurrentArtwork
        }
        return model
    }

    private func requiredArtworkModel(id: ArtworkID) throws -> FurtherSchemaV1.ArtworkModel {
        guard let model = try artworkModels().first(where: { $0.id == id.rawValue }) else {
            throw FurtherStoreError.noCurrentArtwork
        }
        return model
    }

    private func requiredActivityModel(id: ActivityID) throws -> FurtherSchemaV1.ActivityModel {
        guard let model = try activityModels().first(where: { $0.id == id.rawValue }) else {
            throw FurtherStoreError.activityNotFound
        }
        return model
    }

    private func artworkModels() throws -> [FurtherSchemaV1.ArtworkModel] {
        try modelContext.fetch(FetchDescriptor<FurtherSchemaV1.ArtworkModel>())
    }

    private func activityModels() throws -> [FurtherSchemaV1.ActivityModel] {
        try modelContext.fetch(FetchDescriptor<FurtherSchemaV1.ActivityModel>())
    }

    private func artwork(from model: FurtherSchemaV1.ArtworkModel) throws -> Artwork {
        let snapshot = try PersistenceCodec.decode(
            StoredArtworkSnapshot.self,
            from: model.snapshotData
        )
        guard snapshot.id.rawValue == model.id else {
            throw FurtherStoreError.storedIdentityMismatch
        }
        return try snapshot.domainValue()
    }

    private func phase(
        of model: FurtherSchemaV1.ActivityModel
    ) throws -> StoredActivityPhase {
        guard let phase = StoredActivityPhase(rawValue: model.phaseRawValue) else {
            throw PersistenceMappingError.invalidStoredData
        }
        return phase
    }

    private func checkpoint(
        from model: FurtherSchemaV1.ActivityModel
    ) throws -> ActivityCheckpoint {
        guard let data = model.checkpointData else {
            throw PersistenceMappingError.invalidStoredData
        }
        let stored = try PersistenceCodec.decode(StoredCheckpoint.self, from: data)
        guard stored.assignment.activityID.rawValue == model.id,
              stored.assignment.artworkID.rawValue == model.artworkID else {
            throw FurtherStoreError.storedIdentityMismatch
        }
        return try stored.domainValue(
            routeSamples: routeSamples(activityID: stored.assignment.activityID)
        )
    }

    private func reflectionDraft(
        from model: FurtherSchemaV1.ActivityModel
    ) throws -> ReflectionDraft {
        guard let data = model.reflectionDraftData else {
            throw PersistenceMappingError.invalidStoredData
        }
        let draft = try PersistenceCodec.decode(ReflectionDraft.self, from: data)
        return try ReflectionDraft(expression: draft.expression)
    }

    private func requiredStoredRecord(
        from model: FurtherSchemaV1.ActivityModel
    ) throws -> StoredActivityRecord {
        guard let data = model.recordData else {
            throw PersistenceMappingError.invalidStoredData
        }
        let record = try PersistenceCodec.decode(StoredActivityRecord.self, from: data)
        guard record.id.rawValue == model.id,
              record.artworkID.rawValue == model.artworkID else {
            throw FurtherStoreError.storedIdentityMismatch
        }
        return record
    }

    private func record(
        from model: FurtherSchemaV1.ActivityModel
    ) throws -> SharedActivityRecordV1 {
        try requiredStoredRecord(from: model).domainValue(
            routeSamples: routeSamples(activityID: ActivityID(rawValue: model.id))
        )
    }

    private func routeSamples(activityID: ActivityID) throws -> [RouteSample] {
        let models = try modelContext.fetch(FetchDescriptor<FurtherSchemaV1.RouteSampleModel>())
            .filter { $0.activityID == activityID.rawValue }
            .sorted { $0.sequence < $1.sequence }
        guard models.enumerated().allSatisfy({ $0.offset == $0.element.sequence }) else {
            throw PersistenceMappingError.invalidStoredData
        }
        return try models.map {
            try PersistenceCodec.decode(RouteSample.self, from: $0.sampleData)
        }
    }

    private func replaceRouteSamples(
        _ samples: [RouteSample],
        activityID: ActivityID
    ) throws {
        let existing = try modelContext.fetch(FetchDescriptor<FurtherSchemaV1.RouteSampleModel>())
            .filter { $0.activityID == activityID.rawValue }
        existing.forEach(modelContext.delete)

        for (sequence, sample) in samples.enumerated() {
            modelContext.insert(FurtherSchemaV1.RouteSampleModel(
                activityID: activityID.rawValue,
                sequence: sequence,
                sampleData: try PersistenceCodec.encode(sample)
            ))
        }
    }
}
