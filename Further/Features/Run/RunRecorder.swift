import Foundation

enum RunRecorderError: Error, Equatable {
    case alreadyStarted
    case notStarted
    case invalidTransition
    case timeMovedBackward
}

enum RunRecorderPhase: Equatable, Sendable {
    case countdown(remainingSeconds: Int)
    case running
    case paused
    case finished
}

struct RunRecorderSnapshot: Equatable, Sendable {
    let activityID: ActivityID
    let phase: RunRecorderPhase
    let activeDuration: TimeInterval
    let pausedDuration: TimeInterval
    let distance: ActivityDistance?
}

actor RunRecorder {
    static let countdownDuration: TimeInterval = 3

    private enum State {
        case ready
        case countdown(until: Date)
        case running
        case paused
        case finished
    }

    private let store: FurtherStore
    private let timeSource: any TimeSource
    private let environment: RunningEnvironment
    private let timeZone: TimeZone
    private let origin: ActivityOrigin

    private var state = State.ready
    private var assignment: ActivityAssignment?
    private var events: [ActivityEvent] = []

    init(
        store: FurtherStore,
        timeSource: any TimeSource,
        environment: RunningEnvironment,
        timeZone: TimeZone,
        origin: ActivityOrigin
    ) {
        self.store = store
        self.timeSource = timeSource
        self.environment = environment
        self.timeZone = timeZone
        self.origin = origin
    }

    func start() async throws -> RunRecorderSnapshot {
        guard case .ready = state else {
            throw RunRecorderError.alreadyStarted
        }

        let now = await currentTime()
        let activityID = ActivityID()
        let assignment = try await store.startActivity(
            id: activityID,
            environment: environment,
            at: now,
            timeZone: timeZone,
            origin: origin,
            interruptionExpression: try Self.silenceExpression(for: activityID)
        )
        self.assignment = assignment
        state = .countdown(until: now.addingTimeInterval(Self.countdownDuration))
        return try snapshot(at: now)
    }

    func snapshot() async throws -> RunRecorderSnapshot {
        try snapshot(at: await currentTime())
    }

    func pause() async throws -> RunRecorderSnapshot {
        let now = await currentTime()
        _ = try snapshot(at: now)
        guard case .running = state else {
            throw RunRecorderError.invalidTransition
        }

        events.append(ActivityEvent(kind: .paused, occurredAt: now))
        state = .paused
        let snapshot = try snapshot(at: now)
        try await store.saveCheckpoint(try checkpoint(from: snapshot, capturedAt: now))
        return snapshot
    }

    func resume() async throws -> RunRecorderSnapshot {
        let now = await currentTime()
        guard case .paused = state else {
            throw RunRecorderError.invalidTransition
        }

        events.append(ActivityEvent(kind: .resumed, occurredAt: now))
        state = .running
        let snapshot = try snapshot(at: now)
        try await store.saveCheckpoint(try checkpoint(from: snapshot, capturedAt: now))
        return snapshot
    }

    func saveCheckpoint() async throws {
        let now = await currentTime()
        let snapshot = try snapshot(at: now)
        guard snapshot.phase != .finished else { return }
        try await store.saveCheckpoint(try checkpoint(from: snapshot, capturedAt: now))
    }

    func finish() async throws -> SharedActivityRecordV1 {
        let now = await currentTime()
        let snapshot = try snapshot(at: now)
        guard snapshot.phase == .running || snapshot.phase == .paused,
              let assignment else {
            throw RunRecorderError.invalidTransition
        }

        let expression = try Self.silenceExpression(for: assignment.activityID)
        let checkpoint = try checkpoint(from: snapshot, capturedAt: now)
        let record = try SharedActivityRecordV1(
            id: assignment.activityID,
            artworkID: assignment.artworkID,
            origin: origin,
            environment: environment,
            lifecycle: .endedNormally,
            summary: ActivitySummary(
                startedAt: assignment.startedAt,
                endedAt: now,
                startTimeZoneIdentifier: assignment.startTimeZoneIdentifier,
                activeDuration: snapshot.activeDuration,
                pausedDuration: snapshot.pausedDuration,
                distance: snapshot.distance
            ),
            events: events,
            routeSamples: [],
            expression: expression
        )
        try await store.endActivity(
            checkpoint: checkpoint,
            record: record,
            draft: ReflectionDraft(expression: expression)
        )
        state = .finished
        return record
    }

    private func snapshot(at now: Date) throws -> RunRecorderSnapshot {
        guard let assignment else {
            throw RunRecorderError.notStarted
        }
        guard now >= assignment.startedAt,
              events.last.map({ now >= $0.occurredAt }) ?? true else {
            throw RunRecorderError.timeMovedBackward
        }

        if case let .countdown(until) = state, now >= until {
            state = .running
        }

        let pausedDuration = pausedDuration(at: now)
        let activeDuration = now.timeIntervalSince(assignment.startedAt) - pausedDuration
        let phase: RunRecorderPhase = switch state {
        case .ready:
            throw RunRecorderError.notStarted
        case let .countdown(until):
            .countdown(remainingSeconds: max(1, Int(ceil(until.timeIntervalSince(now)))))
        case .running:
            .running
        case .paused:
            .paused
        case .finished:
            .finished
        }

        return RunRecorderSnapshot(
            activityID: assignment.activityID,
            phase: phase,
            activeDuration: activeDuration,
            pausedDuration: pausedDuration,
            distance: nil
        )
    }

    private func currentTime() async -> Date {
        let interval = (await timeSource.now()).timeIntervalSince1970
        return Date(timeIntervalSince1970: floor(interval * 1_000) / 1_000)
    }

    private func pausedDuration(at now: Date) -> TimeInterval {
        var result: TimeInterval = 0
        var pauseStartedAt: Date?

        for event in events {
            switch event.kind {
            case .paused:
                pauseStartedAt = event.occurredAt
            case .resumed:
                if let pauseStartedAt {
                    result += event.occurredAt.timeIntervalSince(pauseStartedAt)
                }
                pauseStartedAt = nil
            }
        }
        if let pauseStartedAt {
            result += now.timeIntervalSince(pauseStartedAt)
        }
        return result
    }

    private func checkpoint(
        from snapshot: RunRecorderSnapshot,
        capturedAt: Date
    ) throws -> ActivityCheckpoint {
        guard let assignment else {
            throw RunRecorderError.notStarted
        }
        return try ActivityCheckpoint(
            assignment: assignment,
            capturedAt: capturedAt,
            activeDuration: snapshot.activeDuration,
            pausedDuration: snapshot.pausedDuration,
            events: events,
            distance: snapshot.distance,
            routeSamples: [],
            origin: origin
        )
    }

    private static func silenceExpression(for activityID: ActivityID) throws -> RecordExpression {
        .silence(
            color: SilenceColor(
                identifier: "silence-\(activityID.rawValue.uuidString.lowercased())",
                generationRuleVersion: "silence-v1",
                value: try RecordColorValue(red: 0.38, green: 0.43, blue: 0.47)
            ),
            note: nil
        )
    }
}
