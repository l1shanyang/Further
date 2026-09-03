import Foundation
import XCTest
@testable import Further

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

    private func makeContext(
        now: Date = Date(timeIntervalSince1970: 1_820_000_000)
    ) async throws -> Context {
        let store = FurtherStore(modelContainer: try FurtherModelContainer.inMemory())
        _ = try await store.createCurrentArtwork(cycle: .time(.oneMonth))
        let timeSource = ControlledTimeSource(now: now)
        let recorder = RunRecorder(
            store: store,
            timeSource: timeSource,
            environment: .indoor,
            timeZone: DomainTestSamples.timeZone,
            origin: DomainTestSamples.origin
        )
        return Context(store: store, timeSource: timeSource, recorder: recorder)
    }
}

private struct Context {
    let store: FurtherStore
    let timeSource: ControlledTimeSource
    let recorder: RunRecorder
}
