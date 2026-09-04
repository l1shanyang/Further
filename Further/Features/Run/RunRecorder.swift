import Foundation

enum RunRecorderError: Error, Equatable {
    case alreadyStarted
    case notStarted
    case invalidTransition
    case timeMovedBackward
    case locationPersistenceFailed
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
    private let locationSource: (any LocationSource)?

    private var state = State.ready
    private var assignment: ActivityAssignment?
    private var events: [ActivityEvent] = []
    private var routeAccumulator = LocationRouteAccumulator()
    private var locationTask: Task<Void, Never>?
    private var samplesAtLastCheckpoint = 0
    private var locationPersistenceFailed = false

    init(
        store: FurtherStore,
        timeSource: any TimeSource,
        environment: RunningEnvironment,
        timeZone: TimeZone,
        origin: ActivityOrigin,
        locationSource: (any LocationSource)? = nil
    ) {
        self.store = store
        self.timeSource = timeSource
        self.environment = environment
        self.timeZone = timeZone
        self.origin = origin
        self.locationSource = locationSource
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
        if environment == .outdoor {
            await startLocationUpdates()
        }
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
        routeAccumulator.breakSegment()
        let snapshot = try snapshot(at: now)
        try await store.saveCheckpoint(try checkpoint(from: snapshot, capturedAt: now))
        samplesAtLastCheckpoint = routeAccumulator.samples.count
        return snapshot
    }

    func resume() async throws -> RunRecorderSnapshot {
        let now = await currentTime()
        guard case .paused = state else {
            throw RunRecorderError.invalidTransition
        }

        events.append(ActivityEvent(kind: .resumed, occurredAt: now))
        state = .running
        routeAccumulator.breakSegment()
        let snapshot = try snapshot(at: now)
        try await store.saveCheckpoint(try checkpoint(from: snapshot, capturedAt: now))
        samplesAtLastCheckpoint = routeAccumulator.samples.count
        return snapshot
    }

    func saveCheckpoint() async throws {
        let now = await currentTime()
        let snapshot = try snapshot(at: now)
        guard snapshot.phase != .finished else { return }
        try await store.saveCheckpoint(try checkpoint(from: snapshot, capturedAt: now))
        samplesAtLastCheckpoint = routeAccumulator.samples.count
    }

    func waitForPendingLocationUpdates() async {
        await locationTask?.value
    }

    func finish() async throws -> SharedActivityRecordV1 {
        let initialTime = await currentTime()
        let currentSnapshot = try snapshot(at: initialTime)
        guard currentSnapshot.phase == .running || currentSnapshot.phase == .paused,
              let assignment else {
            throw RunRecorderError.invalidTransition
        }

        await stopLocationUpdates()
        let endedAt = await currentTime()
        let snapshot = try snapshot(at: endedAt)

        let expression = try Self.silenceExpression(for: assignment.activityID)
        let checkpoint = try checkpoint(from: snapshot, capturedAt: endedAt)
        let record = try SharedActivityRecordV1(
            id: assignment.activityID,
            artworkID: assignment.artworkID,
            origin: origin,
            environment: environment,
            lifecycle: .endedNormally,
            summary: ActivitySummary(
                startedAt: assignment.startedAt,
                endedAt: endedAt,
                startTimeZoneIdentifier: assignment.startTimeZoneIdentifier,
                activeDuration: snapshot.activeDuration,
                pausedDuration: snapshot.pausedDuration,
                distance: snapshot.distance
            ),
            events: events,
            routeSamples: routeAccumulator.samples,
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
        guard !locationPersistenceFailed else {
            throw RunRecorderError.locationPersistenceFailed
        }
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
            distance: routeAccumulator.distance
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
            routeSamples: routeAccumulator.samples,
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

    private func startLocationUpdates() async {
        guard let locationSource, locationTask == nil else { return }
        let stream = await locationSource.startUpdates()
        locationTask = Task { [weak self] in
            for await measurement in stream {
                await self?.record(measurement)
            }
        }
    }

    private func stopLocationUpdates() async {
        let task = locationTask
        if let locationSource {
            await locationSource.stopUpdates()
        }
        await task?.value
        locationTask = nil
    }

    private func record(_ measurement: LocationMeasurement) async {
        guard let assignment, !locationPersistenceFailed else { return }
        let isActive: Bool = switch state {
        case .countdown, .running:
            true
        case .ready, .paused, .finished:
            false
        }

        do {
            try routeAccumulator.record(
                measurement,
                sessionStartedAt: assignment.startedAt,
                isActive: isActive
            )
            if routeAccumulator.samples.count - samplesAtLastCheckpoint >= 20 {
                let capturedAt = await currentTime()
                let snapshot = try snapshot(at: capturedAt)
                try await store.saveCheckpoint(try checkpoint(from: snapshot, capturedAt: capturedAt))
                samplesAtLastCheckpoint = routeAccumulator.samples.count
            }
        } catch {
            locationPersistenceFailed = true
        }
    }
}
