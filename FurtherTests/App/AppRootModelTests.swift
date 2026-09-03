import Foundation
import SwiftData
import XCTest
@testable import Further

@MainActor
final class AppRootModelTests: XCTestCase {
    func testFirstLaunchCreatesBlankTimeArtworkAndRestartRestoresIt() async throws {
        let container = try FurtherModelContainer.inMemory()
        let source = ModelContainerSource { container }
        let now = Date(timeIntervalSince1970: 1_810_000_000)
        let timeSource = ControlledTimeSource(now: now)
        let firstModel = AppRootModel(
            bootstrap: AppBootstrap(containerSource: source, timeSource: timeSource),
            timeSource: timeSource
        )

        await firstModel.start()
        XCTAssertEqual(firstModel.state, .cycleSelection(isCreating: false))

        await firstModel.createArtwork(cycle: .time(.oneMonth))
        guard case let .currentArtwork(firstState) = firstModel.state else {
            return XCTFail("Expected a current artwork")
        }
        XCTAssertEqual(firstState.artwork.state, .blank)
        XCTAssertTrue(firstState.presentation.marks.isEmpty)

        let restartedModel = AppRootModel(
            bootstrap: AppBootstrap(containerSource: source, timeSource: timeSource),
            timeSource: timeSource
        )
        await restartedModel.start()

        guard case let .currentArtwork(restoredState) = restartedModel.state else {
            return XCTFail("Expected restart to restore the current artwork")
        }
        XCTAssertEqual(restoredState.artwork, firstState.artwork)
        XCTAssertEqual(restoredState.artwork.state, .blank)
        XCTAssertEqual(restoredState.presentation, firstState.presentation)
    }

    func testCancellingEndConfirmationRestoresPausedState() async throws {
        let container = try FurtherModelContainer.inMemory()
        let source = ModelContainerSource { container }
        let timeSource = ControlledTimeSource(
            now: Date(timeIntervalSince1970: 1_810_100_000)
        )
        let model = AppRootModel(
            bootstrap: AppBootstrap(containerSource: source, timeSource: timeSource),
            timeSource: timeSource,
            activityOrigin: DomainTestSamples.origin
        )
        await model.start()
        await model.createArtwork(cycle: .time(.oneMonth))
        model.beginRunPreparation()
        model.chooseIndoorRun()
        await model.confirmIndoorRunStart()
        try await timeSource.advance(by: 3)
        await model.refreshRunSnapshot()
        await model.pauseRun()

        guard case let .run(.tracking(paused)) = model.state else {
            return XCTFail("Expected a paused run")
        }
        model.requestRunEnd()
        XCTAssertEqual(model.state, .run(.endingConfirmation(previous: paused)))

        model.cancelRunEnd()
        XCTAssertEqual(model.state, .run(.tracking(paused)))
    }

    func testReturningFromBackgroundRecomputesVisibleTimeFromFacts() async throws {
        let container = try FurtherModelContainer.inMemory()
        let source = ModelContainerSource { container }
        let timeSource = ControlledTimeSource(
            now: Date(timeIntervalSince1970: 1_810_200_000)
        )
        let model = AppRootModel(
            bootstrap: AppBootstrap(containerSource: source, timeSource: timeSource),
            timeSource: timeSource,
            activityOrigin: DomainTestSamples.origin
        )
        await model.start()
        await model.createArtwork(cycle: .time(.oneMonth))
        model.beginRunPreparation()
        model.chooseIndoorRun()
        await model.confirmIndoorRunStart()
        try await timeSource.advance(by: 8)
        await model.appDidEnterBackground()

        try await timeSource.advance(by: 42)
        await model.appBecameActive()

        XCTAssertEqual(
            model.state,
            .run(.tracking(.running(activeDuration: 50)))
        )
    }

    func testSnapshotStartedBeforeEndRequestCannotDismissConfirmation() async throws {
        let container = try FurtherModelContainer.inMemory()
        let source = ModelContainerSource { container }
        let timeSource = SuspendingTimeSource(
            now: Date(timeIntervalSince1970: 1_810_300_000)
        )
        let model = AppRootModel(
            bootstrap: AppBootstrap(containerSource: source, timeSource: timeSource),
            timeSource: timeSource,
            activityOrigin: DomainTestSamples.origin
        )
        await model.start()
        await model.createArtwork(cycle: .time(.oneMonth))
        model.beginRunPreparation()
        model.chooseIndoorRun()
        await model.confirmIndoorRunStart()
        await timeSource.advance(by: 3)
        await model.refreshRunSnapshot()

        await timeSource.suspendNextRead()
        let refresh = Task { await model.refreshRunSnapshot() }
        await timeSource.waitUntilReadIsSuspended()
        model.requestRunEnd()
        guard case let .run(.endingConfirmation(expected)) = model.state else {
            return XCTFail("Expected the end confirmation")
        }

        await timeSource.resumeRead()
        await refresh.value

        XCTAssertEqual(model.state, .run(.endingConfirmation(previous: expected)))
    }

    func testRepeatedPauseAndFinishCommandsAreIgnoredWhileCommandIsInFlight() async throws {
        let container = try FurtherModelContainer.inMemory()
        let source = ModelContainerSource { container }
        let timeSource = ControlledTimeSource(
            now: Date(timeIntervalSince1970: 1_810_400_000)
        )
        let model = AppRootModel(
            bootstrap: AppBootstrap(containerSource: source, timeSource: timeSource),
            timeSource: timeSource,
            activityOrigin: DomainTestSamples.origin
        )
        await model.start()
        await model.createArtwork(cycle: .time(.oneMonth))
        model.beginRunPreparation()
        model.chooseIndoorRun()
        await model.confirmIndoorRunStart()
        try await timeSource.advance(by: 3)
        await model.refreshRunSnapshot()

        let firstPause = Task { await model.pauseRun() }
        let repeatedPause = Task { await model.pauseRun() }
        await firstPause.value
        await repeatedPause.value
        guard case .run(.tracking(.paused)) = model.state else {
            return XCTFail("Expected one successful pause")
        }

        model.requestRunEnd()
        let firstFinish = Task { await model.confirmRunEnd() }
        let repeatedFinish = Task { await model.confirmRunEnd() }
        await firstFinish.value
        await repeatedFinish.value

        guard case .reflection(.expression) = model.state else {
            return XCTFail("Expected one successful transition into reflection")
        }
    }

    func testIndoorReflectionUpdatesArtworkBeforeReturningHome() async throws {
        let container = try FurtherModelContainer.inMemory()
        let source = ModelContainerSource { container }
        let timeSource = ControlledTimeSource(
            now: Date(timeIntervalSince1970: 1_810_500_000)
        )
        let model = AppRootModel(
            bootstrap: AppBootstrap(containerSource: source, timeSource: timeSource),
            timeSource: timeSource,
            activityOrigin: DomainTestSamples.origin
        )
        await model.start()
        await model.createArtwork(cycle: .milestone(.tenKilometers))
        model.beginRunPreparation()
        model.chooseIndoorRun()
        await model.confirmIndoorRunStart()
        try await timeSource.advance(by: 3)
        await model.refreshRunSnapshot()
        model.requestRunEnd()
        await model.confirmRunEnd()

        let color = FeelingColorOption.all[1].color
        model.selectFeelingColor(color)
        model.updateReflectionNote("clear air")
        await model.finishReflectionExpression()
        model.updateIndoorDistance("10")
        await model.saveIndoorDistance()

        guard case let .reflection(.enteringArtwork(recordColor, artwork)) = model.state else {
            return XCTFail("Expected causal artwork-entry feedback")
        }
        XCTAssertEqual(recordColor, color.value)
        XCTAssertEqual(artwork.records.count, 1)
        XCTAssertEqual(artwork.records.first?.expression.note, "clear air")
        XCTAssertEqual(artwork.presentation.marks.count, 1)
        XCTAssertEqual(artwork.presentation.phase, .completed)

        model.showUpdatedArtwork()
        XCTAssertEqual(model.state, .currentArtwork(artwork))
    }
}

private actor SuspendingTimeSource: TimeSource {
    private var currentDate: Date
    private var shouldSuspendNextRead = false
    private var readStartedContinuation: CheckedContinuation<Void, Never>?
    private var readResumeContinuation: CheckedContinuation<Void, Never>?

    init(now: Date) {
        currentDate = now
    }

    func now() async -> Date {
        guard shouldSuspendNextRead else { return currentDate }
        shouldSuspendNextRead = false
        readStartedContinuation?.resume()
        readStartedContinuation = nil
        await withCheckedContinuation { continuation in
            readResumeContinuation = continuation
        }
        return currentDate
    }

    func advance(by duration: TimeInterval) {
        currentDate = currentDate.addingTimeInterval(duration)
    }

    func suspendNextRead() {
        shouldSuspendNextRead = true
    }

    func waitUntilReadIsSuspended() async {
        if readResumeContinuation != nil { return }
        await withCheckedContinuation { continuation in
            readStartedContinuation = continuation
        }
    }

    func resumeRead() {
        readResumeContinuation?.resume()
        readResumeContinuation = nil
    }
}
