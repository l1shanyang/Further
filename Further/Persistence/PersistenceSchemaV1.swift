import Foundation
import SwiftData

enum FurtherSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static let models: [any PersistentModel.Type] = [
        ArtworkModel.self,
        ActivityModel.self,
        RouteSampleModel.self,
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
}

enum FurtherMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [FurtherSchemaV1.self]
    static let stages: [MigrationStage] = []
}
