import Foundation
import SwiftData

enum FurtherModelContainer {
    static func persistent() throws -> ModelContainer {
        let schema = Schema(versionedSchema: FurtherSchemaV2.self)
        let configuration = ModelConfiguration("Further", schema: schema)
        return try make(configuration: configuration, schema: schema)
    }

    static func persistent(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: FurtherSchemaV2.self)
        let configuration = ModelConfiguration("Further", schema: schema, url: url)
        return try make(configuration: configuration, schema: schema)
    }

    static func inMemory() throws -> ModelContainer {
        let schema = Schema(versionedSchema: FurtherSchemaV2.self)
        let configuration = ModelConfiguration(
            "FurtherTests",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try make(configuration: configuration, schema: schema)
    }

    private static func make(
        configuration: ModelConfiguration,
        schema: Schema
    ) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: FurtherMigrationPlan.self,
            configurations: [configuration]
        )
    }
}

struct ModelContainerSource: Sendable {
    private let openContainer: @Sendable () throws -> ModelContainer

    init(openContainer: @escaping @Sendable () throws -> ModelContainer) {
        self.openContainer = openContainer
    }

    func open() throws -> ModelContainer {
        try openContainer()
    }

    static let production = ModelContainerSource {
        try FurtherModelContainer.persistent()
    }

    static let testing = ModelContainerSource {
        try FurtherModelContainer.inMemory()
    }
}
