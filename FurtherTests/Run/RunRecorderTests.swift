import Foundation
import XCTest
@testable import Further

@MainActor
final class RunRecorderTests: XCTestCase {
    func testFinalStartCreatesActivityBeforeCountdownFinishes() async throws {
        let context = try await makeContext()

        let snapshot = try await context.recorder.start()
        let artwork = try await context.store.currentArtwork()

        XCTAssertEqual(snapshot.phase, .countdown(remainingSeconds: 3))
        XCTAssertEqual(snapshot.activeDuration, 0)
        XCTAssertEqual(artwork?.pendingActivityID, snapshot.activityID)
        XCTAssertEqual(artwork?.activityIDs, [snapshot.activityID])
    }

    func testPauseStopsActiveTimeAndResumeContinuesFromIt() async throws {
        let context = try await makeContext()
        _ = try await context.recorder.start()
        try await context.timeSource.advance(by: 3)

        let running = try await context.recorder.snapshot()
        XCTAssertEqual(running.phase, .running)
        XCTAssertEqual(running.activeDuration, 3, accuracy: 0.001)

        _ = try await context.recorder.pause()
        try await context.timeSource.advance(by: 10)
        let paused = try await context.recorder.snapshot()
        XCTAssertEqual(paused.phase, .paused)
        XCTAssertEqual(paused.activeDuration, 3, accuracy: 0.001)
        XCTAssertEqual(paused.pausedDuration, 10, accuracy: 0.001)

        _ = try await context.recorder.resume()
        try await context.timeSource.advance(by: 5)
        let resumed = try await context.recorder.snapshot()
        XCTAssertEqual(resumed.phase, .running)
        XCTAssertEqual(resumed.activeDuration, 8, accuracy: 0.001)
        XCTAssertEqual(resumed.pausedDuration, 10, accuracy: 0.001)
    }

    func testSubmillisecondSystemTimeKeepsCheckpointIdentityStable() async throws {
        let context = try await makeContext(
            now: Date(timeIntervalSince1970: 1_820_000_000.123_456)
        )
        _ = try await context.recorder.start()
        try await context.timeSource.advance(by: 3)

        let paused = try await context.recorder.pause()

        XCTAssertEqual(paused.phase, .paused)
        XCTAssertEqual(paused.activeDuration, 3, accuracy: 0.001)
    }

    func testSnapshotCatchesUpAfterUIUpdatesWereSuspended() async throws {
        let context = try await makeContext()
        _ = try await context.recorder.start()
        try await context.timeSource.advance(by: 8)
        try await context.recorder.saveCheckpoint()

        try await context.timeSource.advance(by: 42)
        let returnedToForeground = try await context.recorder.snapshot()

        XCTAssertEqual(returnedToForeground.phase, .running)
        XCTAssertEqual(returnedToForeground.activeDuration, 50, accuracy: 0.001)
    }

    func testNormalEndAtomicallyCreatesSilentReflectionDraft() async throws {
        let context = try await makeContext()
        let started = try await context.recorder.start()
        try await context.timeSource.advance(by: 12)

        let ended = try await context.recorder.finish()
        let recovery = try await context.store.recoverForBootstrap(
            at: await context.timeSource.now()
        )
        let finalized = try await context.store.activityRecord(id: started.activityID)

        XCTAssertEqual(ended.lifecycle, .endedNormally)
        XCTAssertTrue(ended.expression.isSilence)
        XCTAssertEqual(ended.summary.activeDuration, 12, accuracy: 0.001)
        XCTAssertEqual(recovery.lockedReflectionCount, 1)
        XCTAssertEqual(finalized, ended)
    }

    func testOutdoorRecorderAccumulatesAndPersistsBatchedRoute() async throws {
        let measurements = (0 ..< 405).map { index in
            LocationMeasurement(
                measuredAt: Date(timeIntervalSince1970: 1_820_000_000 + Double(index * 10)),
                latitude: 31 + Double(index) * 0.00005,
                longitude: 121,
                altitudeMeters: 10,
                horizontalAccuracyMeters: 5,
                verticalAccuracyMeters: 8
            )
        }
        let locationSource = TestLocationSource(measurements: measurements)
        let context = try await makeContext(
            environment: .outdoor,
            locationSource: locationSource
        )
        let started = try await context.recorder.start()
        try await context.timeSource.advance(by: 5_000)
        await context.recorder.waitForPendingLocationUpdates()

        let record = try await context.recorder.finish()
        try await context.store.lockExpression(
            ReflectionDraft(expression: record.expression),
            activityID: started.activityID
        )
        let finalized = try await context.store.lockReflection(
            activityID: started.activityID,
            finalizedAt: await context.timeSource.now()
        )

        XCTAssertEqual(record.routeSamples.count, 405)
        XCTAssertEqual(record.routeSamples.filter { $0.quality == .accepted }.count, 405)
        XCTAssertNotNil(record.summary.distance)
        XCTAssertEqual(finalized.routeSamples, record.routeSamples)
        XCTAssertEqual(finalized.summary.distance, record.summary.distance)
        XCTAssertTrue(locationSource.didStop)
    }

    func testFinishingOutdoorRunDrainsAlreadyBufferedLocations() async throws {
        let measurements = (0 ..< 25).map { index in
            LocationMeasurement(
                measuredAt: Date(timeIntervalSince1970: 1_820_000_000 + Double(index * 10)),
                latitude: 31 + Double(index) * 0.00005,
                longitude: 121,
                altitudeMeters: 10,
                horizontalAccuracyMeters: 5,
                verticalAccuracyMeters: 8
            )
        }
        let locationSource = TestLocationSource(measurements: measurements)
        let context = try await makeContext(
            environment: .outdoor,
            locationSource: locationSource
        )
        _ = try await context.recorder.start()
        try await context.timeSource.advance(by: 300)

        let record = try await context.recorder.finish()

        XCTAssertEqual(record.routeSamples.count, measurements.count)
        XCTAssertEqual(record.routeSamples.filter { $0.quality == .accepted }.count, 25)
        XCTAssertTrue(locationSource.didStop)
    }

    func testFinishTimestampFollowsCheckpointWrittenWhileDrainingLocations() async throws {
        let startedAt = Date(timeIntervalSince1970: 1_820_100_000)
        let measurements = (0 ..< 25).map { index in
            LocationMeasurement(
                measuredAt: startedAt.addingTimeInterval(Double(index) * 0.1),
                latitude: 31 + Double(index) * 0.000001,
                longitude: 121,
                altitudeMeters: 10,
                horizontalAccuracyMeters: 5,
                verticalAccuracyMeters: 8
            )
        }
        let store = FurtherStore(modelContainer: try FurtherModelContainer.inMemory())
        _ = try await store.createCurrentArtwork(cycle: .time(.oneMonth))
        let timeSource = AdvancingTimeSource(now: startedAt, increment: 5)
        let recorder = RunRecorder(
            store: store,
            timeSource: timeSource,
            environment: .outdoor,
            timeZone: DomainTestSamples.timeZone,
            origin: DomainTestSamples.origin,
            locationSource: TestLocationSource(measurements: measurements)
        )
        _ = try await recorder.start()

        let record = try await recorder.finish()

        XCTAssertEqual(record.routeSamples.count, 25)
        XCTAssertEqual(record.summary.endedAt, startedAt.addingTimeInterval(15))
    }

    private func makeContext(
        now: Date = Date(timeIntervalSince1970: 1_820_000_000),
        environment: RunningEnvironment = .indoor,
        locationSource: (any LocationSource)? = nil
    ) async throws -> Context {
        let store = FurtherStore(modelContainer: try FurtherModelContainer.inMemory())
        _ = try await store.createCurrentArtwork(cycle: .time(.oneMonth))
        let timeSource = ControlledTimeSource(now: now)
        let recorder = RunRecorder(
            store: store,
            timeSource: timeSource,
            environment: environment,
            timeZone: DomainTestSamples.timeZone,
            origin: DomainTestSamples.origin,
            locationSource: locationSource
        )
        return Context(store: store, timeSource: timeSource, recorder: recorder)
    }
}

@MainActor
private final class TestLocationSource: LocationSource {
    private let measurements: [LocationMeasurement]
    private(set) var didStop = false

    init(measurements: [LocationMeasurement]) {
        self.measurements = measurements
    }

    func currentAuthorization() -> LocationAuthorizationState { .authorized }
    func requestAuthorization() async -> LocationAuthorizationState { .authorized }

    func startUpdates() -> AsyncStream<LocationMeasurement> {
        AsyncStream { continuation in
            measurements.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }

    func stopUpdates() {
        didStop = true
    }
}

private struct Context {
    let store: FurtherStore
    let timeSource: ControlledTimeSource
    let recorder: RunRecorder
}

private actor AdvancingTimeSource: TimeSource {
    private var currentDate: Date
    private let increment: TimeInterval

    init(now: Date, increment: TimeInterval) {
        currentDate = now
        self.increment = increment
    }

    func now() -> Date {
        defer { currentDate = currentDate.addingTimeInterval(increment) }
        return currentDate
    }
}
