import Foundation

enum PersistenceMappingError: Error, Equatable {
    case invalidStoredData
}

enum PersistenceCodec {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(type, from: data)
    }
}

struct StoredArtworkSnapshot: Codable, Sendable {
    let id: ArtworkID
    let cycle: ArtworkCycle
    let visualGenerationVersion: String
    let visualSeed: UUID
    let state: ArtworkState
    let activityIDs: [ActivityID]
    let pendingActivityID: ActivityID?

    init(_ artwork: Artwork) {
        id = artwork.id
        cycle = artwork.cycle
        visualGenerationVersion = artwork.visualGenerationVersion
        visualSeed = artwork.visualSeed
        state = artwork.state
        activityIDs = artwork.activityIDs
        pendingActivityID = artwork.pendingActivityID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case cycle
        case visualGenerationVersion
        case visualSeed
        case state
        case activityIDs
        case pendingActivityID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(ArtworkID.self, forKey: .id)
        cycle = try container.decode(ArtworkCycle.self, forKey: .cycle)
        visualGenerationVersion = try container.decodeIfPresent(
            String.self,
            forKey: .visualGenerationVersion
        ) ?? Artwork.initialVisualGenerationVersion
        visualSeed = try container.decodeIfPresent(UUID.self, forKey: .visualSeed)
            ?? id.rawValue
        state = try container.decode(ArtworkState.self, forKey: .state)
        activityIDs = try container.decode([ActivityID].self, forKey: .activityIDs)
        pendingActivityID = try container.decodeIfPresent(
            ActivityID.self,
            forKey: .pendingActivityID
        )
    }

    func domainValue() throws -> Artwork {
        try Artwork(
            id: id,
            cycle: cycle,
            visualGenerationVersion: visualGenerationVersion,
            visualSeed: visualSeed,
            state: state,
            activityIDs: activityIDs,
            pendingActivityID: pendingActivityID
        )
    }
}

struct StoredCheckpoint: Codable, Sendable {
    let assignment: ActivityAssignment
    let capturedAt: Date
    let activeDuration: TimeInterval
    let pausedDuration: TimeInterval
    let events: [ActivityEvent]
    let distance: ActivityDistance?
    let origin: ActivityOrigin

    init(_ checkpoint: ActivityCheckpoint) {
        assignment = checkpoint.assignment
        capturedAt = checkpoint.capturedAt
        activeDuration = checkpoint.activeDuration
        pausedDuration = checkpoint.pausedDuration
        events = checkpoint.events
        distance = checkpoint.distance
        origin = checkpoint.origin
    }

    func domainValue(routeSamples: [RouteSample]) throws -> ActivityCheckpoint {
        try ActivityCheckpoint(
            assignment: assignment,
            capturedAt: capturedAt,
            activeDuration: activeDuration,
            pausedDuration: pausedDuration,
            events: events,
            distance: distance,
            routeSamples: routeSamples,
            origin: origin
        )
    }
}

struct StoredActivityRecord: Codable, Sendable {
    let id: ActivityID
    let artworkID: ArtworkID
    let origin: ActivityOrigin
    let environment: RunningEnvironment
    let lifecycle: ActivityLifecycle
    let summary: ActivitySummary
    let events: [ActivityEvent]
    let expression: RecordExpression

    init(_ record: SharedActivityRecordV1) {
        id = record.id
        artworkID = record.artworkID
        origin = record.origin
        environment = record.environment
        lifecycle = record.lifecycle
        summary = record.summary
        events = record.events
        expression = record.expression
    }

    func domainValue(
        routeSamples: [RouteSample],
        expression replacementExpression: RecordExpression? = nil
    ) throws -> SharedActivityRecordV1 {
        try SharedActivityRecordV1(
            id: id,
            artworkID: artworkID,
            origin: origin,
            environment: environment,
            lifecycle: lifecycle,
            summary: summary,
            events: events,
            routeSamples: routeSamples,
            expression: replacementExpression ?? expression
        )
    }
}

enum StoredActivityPhase: String, Codable, Sendable {
    case inProgress
    case reflectionDraft
    case reflectionLocked
    case finalized
}
