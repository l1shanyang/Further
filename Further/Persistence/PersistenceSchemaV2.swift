import Foundation
import SwiftData

enum FurtherSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static let models: [any PersistentModel.Type] = [
        ArtworkModel.self,
        ActivityModel.self,
        RouteSampleModel.self,
        HealthExportModel.self,
    ]

    @Model
    final class ArtworkModel {
        @Attribute(.unique) var id: UUID
        var isCurrent: Bool
        var snapshotData: Data

        init(id: UUID, isCurrent: Bool, snapshotData: Data) {
            self.id = id
            self.isCurrent = isCurrent
            self.snapshotData = snapshotData
        }
    }

    @Model
    final class ActivityModel {
        @Attribute(.unique) var id: UUID
        var artworkID: UUID
        var phaseRawValue: String
        var checkpointData: Data?
        var recordData: Data?
        var reflectionDraftData: Data?

        init(
            id: UUID,
            artworkID: UUID,
            phaseRawValue: String,
            checkpointData: Data?,
            recordData: Data?,
            reflectionDraftData: Data?
        ) {
            self.id = id
            self.artworkID = artworkID
            self.phaseRawValue = phaseRawValue
            self.checkpointData = checkpointData
            self.recordData = recordData
            self.reflectionDraftData = reflectionDraftData
        }
    }

    @Model
    final class RouteSampleModel {
        @Attribute(.unique) var id: UUID
        var activityID: UUID
        var sequence: Int
        var sampleData: Data

        init(id: UUID = UUID(), activityID: UUID, sequence: Int, sampleData: Data) {
            self.id = id
            self.activityID = activityID
            self.sequence = sequence
            self.sampleData = sampleData
        }
    }

    @Model
    final class HealthExportModel {
        @Attribute(.unique) var activityID: UUID
        var stateRawValue: String
        var workoutUUID: UUID?
        var routeUUID: UUID?
        var attemptCount: Int

        init(
            activityID: UUID,
            stateRawValue: String,
            workoutUUID: UUID? = nil,
            routeUUID: UUID? = nil,
            attemptCount: Int = 0
        ) {
            self.activityID = activityID
            self.stateRawValue = stateRawValue
            self.workoutUUID = workoutUUID
            self.routeUUID = routeUUID
            self.attemptCount = attemptCount
        }
    }
}

enum FurtherMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [
        FurtherSchemaV1.self,
        FurtherSchemaV2.self,
    ]
    static let stages: [MigrationStage] = [
        .lightweight(fromVersion: FurtherSchemaV1.self, toVersion: FurtherSchemaV2.self),
    ]
}
