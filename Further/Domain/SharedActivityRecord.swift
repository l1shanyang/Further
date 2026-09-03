import Foundation

struct SharedActivityRecordV1: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let id: ActivityID
    let artworkID: ArtworkID
    let origin: ActivityOrigin
    let environment: RunningEnvironment
    let lifecycle: ActivityLifecycle
    let summary: ActivitySummary
    let events: [ActivityEvent]
    let routeSamples: [RouteSample]
    let expression: RecordExpression

    init(
        id: ActivityID,
        artworkID: ArtworkID,
        origin: ActivityOrigin,
        environment: RunningEnvironment,
        lifecycle: ActivityLifecycle,
        summary: ActivitySummary,
        events: [ActivityEvent],
        routeSamples: [RouteSample],
        expression: RecordExpression
    ) throws {
        schemaVersion = Self.schemaVersion
        self.id = id
        self.artworkID = artworkID
        self.origin = origin
        self.environment = environment
        self.lifecycle = lifecycle
        self.summary = summary
        self.events = events
        self.routeSamples = routeSamples
        self.expression = expression
        try validate()
    }

    func validate() throws {
        guard schemaVersion == Self.schemaVersion else {
            throw DomainValidationError.unsupportedSchemaVersion(schemaVersion)
        }

        try summary.validate()
        try routeSamples.forEach { try $0.validate() }
        try expression.recordColor.validate()

        if !lifecycle.isNormalEnd, !expression.isSilence {
            throw DomainValidationError.invalidExpressionForLifecycle
        }

        var expectedEvent = ActivityEventKind.paused
        var lastEventDate = summary.startedAt
        var pauseStartedAt: Date?
        var calculatedPausedDuration: TimeInterval = 0

        for event in events {
            guard event.occurredAt >= lastEventDate,
                  event.occurredAt >= summary.startedAt,
                  event.occurredAt <= summary.endedAt,
                  event.kind == expectedEvent else {
                throw DomainValidationError.invalidActivityEvents
            }

            switch event.kind {
            case .paused:
                pauseStartedAt = event.occurredAt
                expectedEvent = .resumed
            case .resumed:
                guard let pauseStart = pauseStartedAt else {
                    throw DomainValidationError.invalidActivityEvents
                }
                calculatedPausedDuration += event.occurredAt.timeIntervalSince(pauseStart)
                pauseStartedAt = nil
                expectedEvent = .paused
            }

            lastEventDate = event.occurredAt
        }

        if let pauseStartedAt {
            calculatedPausedDuration += summary.endedAt.timeIntervalSince(pauseStartedAt)
        }
        guard abs(calculatedPausedDuration - summary.pausedDuration) < 0.001 else {
            throw DomainValidationError.invalidActivityEvents
        }
    }
}

enum SharedActivityRecordCodec {
    static func encode(_ record: SharedActivityRecordV1) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(record)
    }

    static func decode(_ data: Data) throws -> SharedActivityRecordV1 {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let version = try decoder.decode(VersionProbe.self, from: data).schemaVersion
        guard version == SharedActivityRecordV1.schemaVersion else {
            throw DomainValidationError.unsupportedSchemaVersion(version)
        }

        let record = try decoder.decode(SharedActivityRecordV1.self, from: data)
        try record.validate()
        return record
    }

    private struct VersionProbe: Decodable {
        let schemaVersion: Int
    }
}
