import Foundation

struct ActivityRecordIndexEntry: Identifiable, Equatable, Sendable {
    let id: ActivityID
    let lifecycle: ActivityLifecycle
    let summary: ActivitySummary
    let expression: RecordExpression

    init(
        id: ActivityID,
        lifecycle: ActivityLifecycle,
        summary: ActivitySummary,
        expression: RecordExpression
    ) {
        self.id = id
        self.lifecycle = lifecycle
        self.summary = summary
        self.expression = expression
    }

    init(record: SharedActivityRecordV1) {
        self.init(
            id: record.id,
            lifecycle: record.lifecycle,
            summary: record.summary,
            expression: record.expression
        )
    }
}
