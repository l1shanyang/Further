import Foundation
import Observation

struct CurrentArtworkViewState: Equatable, Sendable {
    let artwork: Artwork
    let records: [SharedActivityRecordV1]
    let presentation: BasicArtworkDescription

    init(artwork: Artwork, records: [SharedActivityRecordV1]) {
        self.artwork = artwork
        self.records = records
        presentation = BasicArtworkRenderer.render(artwork: artwork, records: records)
    }
}

enum AppRootState: Equatable, Sendable {
    case loading
    case cycleSelection(isCreating: Bool)
    case currentArtwork(CurrentArtworkViewState)
    case run(RunFlowViewState)
    case blocked
}

@MainActor
@Observable
final class AppRootModel {
    private(set) var state: AppRootState = .loading
    private(set) var recoveryNotice: AppBootstrapNotice?
    private(set) var isRunCommandInFlight = false

    private let bootstrap: AppBootstrap
    private let timeSource: any TimeSource
    private let activityOrigin: ActivityOrigin
    private var store: FurtherStore?
    private var isStarting = false
    private var artworkBeforeRun: CurrentArtworkViewState?
    private var recorder: RunRecorder?
    private var runUpdateTask: Task<Void, Never>?

    init(
        bootstrap: AppBootstrap,
        timeSource: any TimeSource,
        activityOrigin: ActivityOrigin = ActivityOrigin(
            productIdentifier: "com.example.Further",
            productVersion: "testing",
            deviceModel: nil,
            operatingSystemVersion: nil
        )
    ) {
        self.bootstrap = bootstrap
        self.timeSource = timeSource
        self.activityOrigin = activityOrigin
    }

    func start() async {
        guard !isStarting else { return }
        isStarting = true
        state = .loading
        defer { isStarting = false }

        switch await bootstrap.start() {
        case let .ready(app):
            store = app.store
            recoveryNotice = app.notice
            switch app.route {
            case .artworkSelection:
                state = .cycleSelection(isCreating: false)
            case let .currentArtwork(id):
                await loadCurrentArtwork(id: id)
            }
        case .blocked:
            state = .blocked
        }
    }

    func createArtwork(cycle: ArtworkCycle) async {
        guard case .cycleSelection = state, let store else { return }
        state = .cycleSelection(isCreating: true)

        do {
            let artwork = try await store.createCurrentArtwork(cycle: cycle)
            state = .currentArtwork(CurrentArtworkViewState(artwork: artwork, records: []))
        } catch {
            state = .blocked
        }
    }

    func refreshCurrentArtwork() async {
        guard case .currentArtwork = state, let store else { return }

        do {
            guard let artwork = try await store.evaluateCurrentArtwork(
                at: await timeSource.now()
            ) else {
                state = .cycleSelection(isCreating: false)
                return
            }
            let records = try await store.records(for: artwork.id)
            state = .currentArtwork(CurrentArtworkViewState(
                artwork: artwork,
                records: records
            ))
        } catch {
            state = .blocked
        }
    }

    func beginRunPreparation() {
        guard case let .currentArtwork(artwork) = state,
              artwork.presentation.phase != .completed else { return }
        artworkBeforeRun = artwork
        state = .run(.environmentSelection)
    }

    func chooseIndoorRun() {
        guard state == .run(.environmentSelection) else { return }
        state = .run(.readyIndoor(isStarting: false))
    }

    func cancelRunPreparation() {
        guard case let .run(runState) = state,
              runState == .environmentSelection || runState == .readyIndoor(isStarting: false),
              let artworkBeforeRun else { return }
        state = .currentArtwork(artworkBeforeRun)
        self.artworkBeforeRun = nil
    }

    func confirmIndoorRunStart() async {
        guard state == .run(.readyIndoor(isStarting: false)),
              let store else { return }
        state = .run(.readyIndoor(isStarting: true))

        let recorder = RunRecorder(
            store: store,
            timeSource: timeSource,
            environment: .indoor,
            timeZone: .current,
            origin: activityOrigin
        )
        self.recorder = recorder

        do {
            apply(try await recorder.start())
            startRunUpdates()
        } catch {
            state = .blocked
        }
    }

    func pauseRun() async {
        guard case .run(.tracking(.running)) = state,
              !isRunCommandInFlight,
              let recorder else { return }
        let expectedState = state
        isRunCommandInFlight = true
        defer { isRunCommandInFlight = false }

        do {
            let snapshot = try await recorder.pause()
            guard state == expectedState else { return }
            apply(snapshot)
        } catch {
            if state == expectedState {
                state = .blocked
            }
        }
    }

    func resumeRun() async {
        guard case .run(.tracking(.paused)) = state,
              !isRunCommandInFlight,
              let recorder else { return }
        let expectedState = state
        isRunCommandInFlight = true
        defer { isRunCommandInFlight = false }

        do {
            let snapshot = try await recorder.resume()
            guard state == expectedState else { return }
            apply(snapshot)
        } catch {
            if state == expectedState {
                state = .blocked
            }
        }
    }

    func requestRunEnd() {
        guard case let .run(.tracking(previous)) = state,
              !isRunCommandInFlight else { return }
        state = .run(.endingConfirmation(previous: previous))
    }

    func cancelRunEnd() {
        guard case let .run(.endingConfirmation(previous)) = state,
              !isRunCommandInFlight else { return }
        state = .run(.tracking(previous))
    }

    func confirmRunEnd() async {
        guard case .run(.endingConfirmation) = state,
              !isRunCommandInFlight,
              let recorder else { return }
        let expectedState = state
        isRunCommandInFlight = true
        runUpdateTask?.cancel()
        runUpdateTask = nil
        defer { isRunCommandInFlight = false }

        do {
            let record = try await recorder.finish()
            guard state == expectedState else { return }
            state = .run(.awaitingReflection(activityID: record.id))
        } catch {
            if state == expectedState {
                state = .blocked
            }
        }
    }

    func appDidEnterBackground() async {
        runUpdateTask?.cancel()
        runUpdateTask = nil
        guard let recorder,
              case let .run(runState) = state,
              runState.hasPersistedSession else { return }
        do {
            try await recorder.saveCheckpoint()
        } catch {
            state = .blocked
        }
    }

    func appBecameActive() async {
        if case let .run(runState) = state, runState.hasLiveSession {
            await refreshRunSnapshot()
            if case let .run(refreshedState) = state, refreshedState.hasLiveSession {
                startRunUpdates()
            }
        } else if case .currentArtwork = state {
            await refreshCurrentArtwork()
        }
    }

    func refreshRunSnapshot() async {
        guard let recorder,
              case let .run(runState) = state,
              !runState.isEndingOrFinished,
              !isRunCommandInFlight else { return }
        let expectedState = state

        do {
            let snapshot = try await recorder.snapshot()
            guard state == expectedState, !isRunCommandInFlight else { return }
            apply(snapshot)
        } catch {
            if state == expectedState, !isRunCommandInFlight {
                state = .blocked
            }
        }
    }

    func dismissRecoveryNotice() {
        recoveryNotice = nil
    }

    private func loadCurrentArtwork(id: ArtworkID) async {
        guard let store else {
            state = .blocked
            return
        }

        do {
            guard let artwork = try await store.currentArtwork(), artwork.id == id else {
                state = .blocked
                return
            }
            let records = try await store.records(for: id)
            state = .currentArtwork(CurrentArtworkViewState(
                artwork: artwork,
                records: records
            ))
        } catch {
            state = .blocked
        }
    }

    private func apply(_ snapshot: RunRecorderSnapshot) {
        switch snapshot.phase {
        case let .countdown(remainingSeconds):
            state = .run(.countdown(remainingSeconds: remainingSeconds))
        case .running:
            state = .run(.tracking(.running(activeDuration: snapshot.activeDuration)))
        case .paused:
            state = .run(.tracking(.paused(activeDuration: snapshot.activeDuration)))
        case .finished:
            break
        }
    }

    private func startRunUpdates() {
        guard runUpdateTask == nil else { return }
        runUpdateTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(250))
                } catch {
                    return
                }
                guard let self else { return }
                await self.refreshRunSnapshot()
            }
        }
    }
}

private extension RunFlowViewState {
    var isEndingOrFinished: Bool {
        switch self {
        case .endingConfirmation, .awaitingReflection:
            true
        case .environmentSelection, .readyIndoor, .countdown, .tracking:
            false
        }
    }

    var hasPersistedSession: Bool {
        switch self {
        case .countdown, .tracking, .endingConfirmation:
            true
        case .environmentSelection, .readyIndoor, .awaitingReflection:
            false
        }
    }

    var hasLiveSession: Bool {
        hasPersistedSession
    }
}
