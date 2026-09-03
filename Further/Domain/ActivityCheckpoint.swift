import Foundation

struct ActivityCheckpoint: Codable, Equatable, Sendable {
    let assignment: ActivityAssignment
    let capturedAt: Date
    let activeDuration: TimeInterval
    let pausedDuration: TimeInterval
    let events: [ActivityEvent]
    let distance: ActivityDistance?
    let routeSamples: [RouteSample]
    let origin: ActivityOrigin

    init(
        assignment: ActivityAssignment,
        capturedAt: Date,
        activeDuration: TimeInterval,
        pausedDuration: TimeInterval,
        events: [ActivityEvent],
        distance: ActivityDistance?,
        routeSamples: [RouteSample],
        origin: ActivityOrigin
    ) throws {
        self.assignment = assignment
        self.capturedAt = capturedAt
        self.activeDuration = activeDuration
        self.pausedDuration = pausedDuration
        self.events = events
        self.distance = distance
        self.routeSamples = routeSamples
        self.origin = origin
        try validate()
    }

    func validate() throws {
        let summary = try ActivitySummary(
            startedAt: assignment.startedAt,
            endedAt: capturedAt,
            startTimeZoneIdentifier: assignment.startTimeZoneIdentifier,
            activeDuration: activeDuration,
            pausedDuration: pausedDuration,
            distance: distance
        )
        let validationColor = try RecordColorValue(red: 0, green: 0, blue: 0)
        let validationSilence = SilenceColor(
            identifier: "checkpoint-validation",
            generationRuleVersion: "1",
            value: validationColor
        )
        _ = try SharedActivityRecordV1(
            id: assignment.activityID,
            artworkID: assignment.artworkID,
            origin: origin,
            environment: assignment.environment,
            lifecycle: .technicalInterruption(.unknownTechnicalFailure),
            summary: summary,
            events: events,
            routeSamples: routeSamples,
            expression: .silence(color: validationSilence, note: nil)
        )
    }

    func interruptedRecord(
        reason: TechnicalInterruptionReason,
        expression: RecordExpression
    ) throws -> SharedActivityRecordV1 {
        guard expression.isSilence else {
            throw DomainValidationError.invalidExpressionForLifecycle
        }

        return try SharedActivityRecordV1(
            id: assignment.activityID,
            artworkID: assignment.artworkID,
            origin: origin,
            environment: assignment.environment,
            lifecycle: .technicalInterruption(reason),
            summary: ActivitySummary(
                startedAt: assignment.startedAt,
                endedAt: capturedAt,
                startTimeZoneIdentifier: assignment.startTimeZoneIdentifier,
                activeDuration: activeDuration,
                pausedDuration: pausedDuration,
                distance: distance
            ),
            events: events,
            routeSamples: routeSamples,
            expression: expression
        )
    }
}
