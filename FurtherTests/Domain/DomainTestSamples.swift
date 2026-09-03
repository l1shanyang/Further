import Foundation
@testable import Further

enum DomainTestSamples {
    static let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    static let origin = ActivityOrigin(
        productIdentifier: "com.lishanyang.Further",
        productVersion: "0.1.0",
        deviceModel: "iPhone",
        operatingSystemVersion: "26.2"
    )

    static func silenceExpression(note: String? = nil) throws -> RecordExpression {
        .silence(
            color: SilenceColor(
                identifier: "silence-1",
                generationRuleVersion: "1",
                value: try RecordColorValue(red: 0.2, green: 0.3, blue: 0.4)
            ),
            note: note
        )
    }

    static func record(
        assignment: ActivityAssignment,
        endedAt: Date,
        lifecycle: ActivityLifecycle = .endedNormally,
        distance: ActivityDistance? = nil,
        pausedDuration: TimeInterval = 0,
        events: [ActivityEvent] = [],
        routeSamples: [RouteSample] = [],
        expression: RecordExpression? = nil
    ) throws -> SharedActivityRecordV1 {
        try SharedActivityRecordV1(
            id: assignment.activityID,
            artworkID: assignment.artworkID,
            origin: origin,
            environment: assignment.environment,
            lifecycle: lifecycle,
            summary: try ActivitySummary(
                startedAt: assignment.startedAt,
                endedAt: endedAt,
                startTimeZoneIdentifier: assignment.startTimeZoneIdentifier,
                activeDuration: endedAt.timeIntervalSince(assignment.startedAt) - pausedDuration,
                pausedDuration: pausedDuration,
                distance: distance
            ),
            events: events,
            routeSamples: routeSamples,
            expression: try expression ?? silenceExpression()
        )
    }
}
