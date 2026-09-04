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

enum HealthExportPersistenceState: String, Equatable, Sendable {
    case pending
    case authorizationDenied
    case retryPending
    case exported
}

struct HealthExportJob: Equatable, Sendable {
    let record: SharedActivityRecordV1
    let state: HealthExportPersistenceState
    let attemptCount: Int
}

struct HealthExportSnapshot: Equatable, Sendable {
    let state: HealthExportPersistenceState
    let workoutUUID: UUID?
    let routeUUID: UUID?
    let attemptCount: Int
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
            let model = FurtherSchemaV2.ArtworkModel(
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

    func allRecordIndexEntries() throws -> [ActivityRecordIndexEntry] {
        try activityModels().compactMap { model in
            guard try phase(of: model) == .finalized else { return nil }
            let stored = try requiredStoredRecord(from: model)
            return ActivityRecordIndexEntry(
                id: stored.id,
                lifecycle: stored.lifecycle,
                summary: stored.summary,
                expression: stored.expression
            )
        }
    }

    func healthExportJobs(
        includeAuthorizationDenied: Bool
    ) throws -> [HealthExportJob] {
        try healthExportModels().compactMap { model -> HealthExportJob? in
            let state = try healthExportState(of: model)
            let shouldExport = switch state {
            case .pending, .retryPending: true
            case .authorizationDenied: includeAuthorizationDenied
            case .exported: false
            }
            guard shouldExport else { return nil }
            let activity = try requiredActivityModel(
                id: ActivityID(rawValue: model.activityID)
            )
            guard try phase(of: activity) == .finalized else {
                throw PersistenceMappingError.invalidStoredData
            }
            return HealthExportJob(
                record: try record(from: activity),
                state: state,
                attemptCount: model.attemptCount
            )
        }
    }

    func healthExportSnapshot(activityID: ActivityID) throws -> HealthExportSnapshot? {
        guard let model = try healthExportModel(activityID: activityID) else { return nil }
        return HealthExportSnapshot(
            state: try healthExportState(of: model),
            workoutUUID: model.workoutUUID,
            routeUUID: model.routeUUID,
            attemptCount: model.attemptCount
        )
    }

    func markHealthExportAuthorizationDenied(activityID: ActivityID) throws {
        try updateHealthExport(activityID: activityID) { model in
            model.stateRawValue = HealthExportPersistenceState.authorizationDenied.rawValue
        }
    }

    func markHealthExportRetryPending(activityID: ActivityID) throws {
        try updateHealthExport(activityID: activityID) { model in
            model.stateRawValue = HealthExportPersistenceState.retryPending.rawValue
            model.attemptCount += 1
        }
    }

    func markHealthExported(
        activityID: ActivityID,
        receipt: HealthWriteReceipt
    ) throws {
        try updateHealthExport(activityID: activityID) { model in
            model.stateRawValue = HealthExportPersistenceState.exported.rawValue
            model.workoutUUID = receipt.workoutUUID
            model.routeUUID = receipt.routeUUID
            model.attemptCount += 1
        }
    }

    func artworkCollection() throws -> [ArtworkCollectionEntry] {
        let archived = try artworkModels().compactMap { model -> Artwork? in
            let artwork = try artwork(from: model)
            guard case .archived = artwork.state else { return nil }
            return artwork
        }
        let activityModelsByID = Dictionary(
            uniqueKeysWithValues: try activityModels().map { ($0.id, $0) }
        )

        return try archived.map { artwork in
            let records = try artwork.activityIDs.map { activityID in
                guard let model = activityModelsByID[activityID.rawValue],
                      try phase(of: model) == .finalized else {
                    throw PersistenceMappingError.invalidStoredData
                }
                let stored = try requiredStoredRecord(from: model)
                return ActivityRecordIndexEntry(
                    id: stored.id,
                    lifecycle: stored.lifecycle,
                    summary: stored.summary,
                    expression: stored.expression
                )
            }
            return try ArtworkCollectionEntry(artwork: artwork, records: records)
        }
        .sorted {
            if completedAt($0.artwork) != completedAt($1.artwork) {
                return completedAt($0.artwork) > completedAt($1.artwork)
            }
            return $0.id.rawValue.uuidString > $1.id.rawValue.uuidString
        }
    }

    func startNextArtwork(
        cycle: ArtworkCycle,
        archivedAt: Date,
        id: ArtworkID = ArtworkID()
    ) throws -> Artwork {
        try transaction {
            let previousModel = try requiredCurrentArtworkModel()
            var previous = try artwork(from: previousModel)
            try previous.archive(at: archivedAt)

            let next = Artwork(id: id, cycle: cycle)
            previousModel.snapshotData = try PersistenceCodec.encode(
                StoredArtworkSnapshot(previous)
            )
            previousModel.isCurrent = false
            modelContext.insert(FurtherSchemaV2.ArtworkModel(
                id: id.rawValue,
                isCurrent: true,
                snapshotData: try PersistenceCodec.encode(StoredArtworkSnapshot(next))
            ))
            return next
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
        if let artwork = try evaluateCurrentArtwork(at: startedAt),
           case .completed = artwork.state {
            throw DomainValidationError.artworkNotAcceptingActivities
        }

        return try transaction {
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
            modelContext.insert(FurtherSchemaV2.ActivityModel(
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
            try appendRouteSamples(
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
            try appendRouteSamples(record.routeSamples, activityID: record.id)
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
            try appendRouteSamples(record.routeSamples, activityID: record.id)
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

    func lockExpression(
        _ draft: ReflectionDraft,
        activityID: ActivityID
    ) throws {
        try transaction {
            let activityModel = try requiredActivityModel(id: activityID)
            guard try phase(of: activityModel) == .reflectionDraft else {
                throw FurtherStoreError.invalidActivityPhase
            }
            activityModel.reflectionDraftData = try PersistenceCodec.encode(draft)
            activityModel.phaseRawValue = StoredActivityPhase.reflectionLocked.rawValue
        }
    }

    @discardableResult
    func lockReflection(
        activityID: ActivityID,
        manualDistanceMeters: Double? = nil,
        finalizedAt: Date
    ) throws -> SharedActivityRecordV1 {
        try transaction {
            let activityModel = try requiredActivityModel(id: activityID)
            guard try phase(of: activityModel) == .reflectionLocked else {
                throw FurtherStoreError.invalidActivityPhase
            }
            return try lockReflection(
                activityModel,
                manualDistanceMeters: manualDistanceMeters,
                finalizedAt: finalizedAt
            )
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
                case .reflectionLocked:
                    _ = try lockReflection(activityModel, finalizedAt: date)
                    lockedCount += 1
                case .finalized:
                    try ensureHealthExport(for: activityModel)
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
        _ activityModel: FurtherSchemaV2.ActivityModel,
        manualDistanceMeters: Double? = nil,
        finalizedAt: Date
    ) throws -> SharedActivityRecordV1 {
        let draft = try reflectionDraft(from: activityModel)
        let stored = try requiredStoredRecord(from: activityModel)
        let routes = try routeSamples(activityID: ActivityID(rawValue: activityModel.id))
        let storedRecord = try stored.domainValue(
            routeSamples: routes,
            expression: draft.expression
        )
        guard manualDistanceMeters == nil || storedRecord.environment == .indoor else {
            throw FurtherStoreError.invalidActivityPhase
        }
        let distance = try manualDistanceMeters.map {
            try ActivityDistance(meters: $0, source: .manualEntry)
        }
        let summary = try ActivitySummary(
            startedAt: storedRecord.summary.startedAt,
            endedAt: storedRecord.summary.endedAt,
            startTimeZoneIdentifier: storedRecord.summary.startTimeZoneIdentifier,
            activeDuration: storedRecord.summary.activeDuration,
            pausedDuration: storedRecord.summary.pausedDuration,
            distance: distance ?? storedRecord.summary.distance
        )
        let record = try SharedActivityRecordV1(
            id: storedRecord.id,
            artworkID: storedRecord.artworkID,
            origin: storedRecord.origin,
            environment: storedRecord.environment,
            lifecycle: storedRecord.lifecycle,
            summary: summary,
            events: storedRecord.events,
            routeSamples: storedRecord.routeSamples,
            expression: storedRecord.expression
        )
        try finalize(record, activityModel: activityModel, finalizedAt: finalizedAt)
        return record
    }

    private func finalize(
        _ record: SharedActivityRecordV1,
        activityModel: FurtherSchemaV2.ActivityModel,
        finalizedAt: Date
    ) throws {
        guard activityModel.id == record.id.rawValue,
              activityModel.artworkID == record.artworkID.rawValue else {
            throw FurtherStoreError.storedIdentityMismatch
        }
        let artworkModel = try requiredArtworkModel(id: record.artworkID)
        var artwork = try artwork(from: artworkModel)
        try artwork.include(record, finalizedAt: finalizedAt)
        artwork.evaluate(at: finalizedAt)

        artworkModel.snapshotData = try PersistenceCodec.encode(StoredArtworkSnapshot(artwork))
        activityModel.phaseRawValue = StoredActivityPhase.finalized.rawValue
        activityModel.checkpointData = nil
        activityModel.recordData = try PersistenceCodec.encode(StoredActivityRecord(record))
        activityModel.reflectionDraftData = nil
        try appendRouteSamples(record.routeSamples, activityID: record.id)
        try ensureHealthExport(for: activityModel)
    }

    private func ensureHealthExport(
        for activityModel: FurtherSchemaV2.ActivityModel
    ) throws {
        let activityID = ActivityID(rawValue: activityModel.id)
        if try healthExportModel(activityID: activityID) == nil {
            modelContext.insert(FurtherSchemaV2.HealthExportModel(
                activityID: activityID.rawValue,
                stateRawValue: HealthExportPersistenceState.pending.rawValue
            ))
        }
    }

    private func updateHealthExport(
        activityID: ActivityID,
        update: (FurtherSchemaV2.HealthExportModel) -> Void
    ) throws {
        try transaction {
            guard let model = try healthExportModel(activityID: activityID) else {
                throw FurtherStoreError.activityNotFound
            }
            update(model)
        }
    }

    private func healthExportModels() throws -> [FurtherSchemaV2.HealthExportModel] {
        try modelContext.fetch(FetchDescriptor<FurtherSchemaV2.HealthExportModel>())
    }

    private func healthExportModel(
        activityID: ActivityID
    ) throws -> FurtherSchemaV2.HealthExportModel? {
        let id = activityID.rawValue
        var descriptor = FetchDescriptor<FurtherSchemaV2.HealthExportModel>(
            predicate: #Predicate { $0.activityID == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func healthExportState(
        of model: FurtherSchemaV2.HealthExportModel
    ) throws -> HealthExportPersistenceState {
        guard let state = HealthExportPersistenceState(rawValue: model.stateRawValue) else {
            throw PersistenceMappingError.invalidStoredData
        }
        return state
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

    private func completedAt(_ artwork: Artwork) -> Date {
        guard case let .archived(_, completedAt, _) = artwork.state else {
            return .distantPast
        }
        return completedAt
    }

    private func currentArtworkModels() throws -> [FurtherSchemaV2.ArtworkModel] {
        try artworkModels().filter(\.isCurrent)
    }

    private func singleCurrentArtworkModel() throws -> FurtherSchemaV2.ArtworkModel? {
        let models = try currentArtworkModels()
        guard models.count <= 1 else {
            throw FurtherStoreError.multipleCurrentArtworks
        }
        return models.first
    }

    private func requiredCurrentArtworkModel() throws -> FurtherSchemaV2.ArtworkModel {
        guard let model = try singleCurrentArtworkModel() else {
            throw FurtherStoreError.noCurrentArtwork
        }
        return model
    }

    private func requiredArtworkModel(id: ArtworkID) throws -> FurtherSchemaV2.ArtworkModel {
        guard let model = try artworkModels().first(where: { $0.id == id.rawValue }) else {
            throw FurtherStoreError.noCurrentArtwork
        }
        return model
    }

    private func requiredActivityModel(id: ActivityID) throws -> FurtherSchemaV2.ActivityModel {
        guard let model = try activityModels().first(where: { $0.id == id.rawValue }) else {
            throw FurtherStoreError.activityNotFound
        }
        return model
    }

    private func artworkModels() throws -> [FurtherSchemaV2.ArtworkModel] {
        try modelContext.fetch(FetchDescriptor<FurtherSchemaV2.ArtworkModel>())
    }

    private func activityModels() throws -> [FurtherSchemaV2.ActivityModel] {
        try modelContext.fetch(FetchDescriptor<FurtherSchemaV2.ActivityModel>())
    }

    private func artwork(from model: FurtherSchemaV2.ArtworkModel) throws -> Artwork {
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
        of model: FurtherSchemaV2.ActivityModel
    ) throws -> StoredActivityPhase {
        guard let phase = StoredActivityPhase(rawValue: model.phaseRawValue) else {
            throw PersistenceMappingError.invalidStoredData
        }
        return phase
    }

    private func checkpoint(
        from model: FurtherSchemaV2.ActivityModel
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
        from model: FurtherSchemaV2.ActivityModel
    ) throws -> ReflectionDraft {
        guard let data = model.reflectionDraftData else {
            throw PersistenceMappingError.invalidStoredData
        }
        let draft = try PersistenceCodec.decode(ReflectionDraft.self, from: data)
        return try ReflectionDraft(expression: draft.expression)
    }

    private func requiredStoredRecord(
        from model: FurtherSchemaV2.ActivityModel
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
        from model: FurtherSchemaV2.ActivityModel
    ) throws -> SharedActivityRecordV1 {
        try requiredStoredRecord(from: model).domainValue(
            routeSamples: routeSamples(activityID: ActivityID(rawValue: model.id))
        )
    }

    private func routeSamples(activityID: ActivityID) throws -> [RouteSample] {
        let models = try modelContext.fetch(FetchDescriptor<FurtherSchemaV2.RouteSampleModel>())
            .filter { $0.activityID == activityID.rawValue }
            .sorted { $0.sequence < $1.sequence }
        guard models.enumerated().allSatisfy({ $0.offset == $0.element.sequence }) else {
            throw PersistenceMappingError.invalidStoredData
        }
        return try models.map {
            try PersistenceCodec.decode(RouteSample.self, from: $0.sampleData)
        }
    }

    private func appendRouteSamples(
        _ samples: [RouteSample],
        activityID: ActivityID
    ) throws {
        let existing = try modelContext.fetch(FetchDescriptor<FurtherSchemaV2.RouteSampleModel>())
            .filter { $0.activityID == activityID.rawValue }
            .sorted { $0.sequence < $1.sequence }
        guard existing.enumerated().allSatisfy({ $0.offset == $0.element.sequence }),
              samples.count >= existing.count,
              try zip(samples, existing).allSatisfy({ sample, model in
                  try PersistenceCodec.encode(sample) == model.sampleData
              }) else {
            throw FurtherStoreError.storedIdentityMismatch
        }

        for (sequence, sample) in samples.enumerated().dropFirst(existing.count) {
            modelContext.insert(FurtherSchemaV2.RouteSampleModel(
                activityID: activityID.rawValue,
                sequence: sequence,
                sampleData: try PersistenceCodec.encode(sample)
            ))
        }
    }
}
