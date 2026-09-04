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
    case reflection(ReflectionFlowViewState)
    case blocked
}

@MainActor
@Observable
final class AppRootModel {
    private(set) var state: AppRootState = .loading
    private(set) var recoveryNotice: AppBootstrapNotice?
    private(set) var isRunCommandInFlight = false
    private(set) var isReflectionCommandInFlight = false

    private let bootstrap: AppBootstrap
    private let timeSource: any TimeSource
    private let locationSource: any LocationSource
    private let activityOrigin: ActivityOrigin
    private var store: FurtherStore?
    private var isStarting = false
    private var artworkBeforeRun: CurrentArtworkViewState?
    private var recorder: RunRecorder?
    private var runUpdateTask: Task<Void, Never>?
    private var reflectionDraftSaveTask: Task<Void, Never>?

    init(
        bootstrap: AppBootstrap,
        timeSource: any TimeSource,
        locationSource: any LocationSource = UnavailableLocationSource(),
        activityOrigin: ActivityOrigin = ActivityOrigin(
            productIdentifier: "com.example.Further",
            productVersion: "testing",
            deviceModel: nil,
            operatingSystemVersion: nil
        )
    ) {
        self.bootstrap = bootstrap
        self.timeSource = timeSource
        self.locationSource = locationSource
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

    func chooseOutdoorRun() async {
        guard state == .run(.environmentSelection) else { return }
        let authorization = await locationSource.requestAuthorization()
        guard state == .run(.environmentSelection) else { return }
        state = .run(.readyOutdoor(authorization: authorization, isStarting: false))
    }

    func cancelRunPreparation() {
        guard case let .run(runState) = state,
              runState.canCancelPreparation,
              let artworkBeforeRun else { return }
        state = .currentArtwork(artworkBeforeRun)
        self.artworkBeforeRun = nil
    }

    func confirmIndoorRunStart() async {
        await confirmRunStart(environment: .indoor)
    }

    func confirmOutdoorRunStart() async {
        await confirmRunStart(environment: .outdoor)
    }

    func confirmSelectedRunStart() async {
        switch state {
        case .run(.readyIndoor):
            await confirmIndoorRunStart()
        case .run(.readyOutdoor):
            await confirmOutdoorRunStart()
        default:
            break
        }
    }

    private func confirmRunStart(environment: RunningEnvironment) async {
        guard let store else { return }
        switch (environment, state) {
        case (.indoor, .run(.readyIndoor(isStarting: false))):
            state = .run(.readyIndoor(isStarting: true))
        case let (.outdoor, .run(.readyOutdoor(authorization, isStarting: false))):
            state = .run(.readyOutdoor(authorization: authorization, isStarting: true))
        default:
            return
        }

        let recorder = RunRecorder(
            store: store,
            timeSource: timeSource,
            environment: environment,
            timeZone: .current,
            origin: activityOrigin,
            locationSource: environment == .outdoor ? locationSource : nil
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
            guard case let .silence(color, note) = record.expression else {
                state = .blocked
                return
            }
            state = .reflection(.expression(ReflectionExpressionState(
                activityID: record.id,
                environment: record.environment,
                silenceColor: color,
                feelingColor: nil,
                note: note ?? ""
            )))
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

    func selectFeelingColor(_ color: FeelingColor) {
        updateReflectionExpression { expression in
            expression.feelingColor = color
        }
    }

    func updateReflectionNote(_ note: String) {
        updateReflectionExpression { expression in
            expression.note = note
        }
    }

    func finishReflectionExpression() async {
        await finishReflectionExpression(keepingSilence: false)
    }

    func keepReflectionSilent() async {
        await finishReflectionExpression(keepingSilence: true)
    }

    func updateIndoorDistance(_ kilometers: String) {
        guard case var .reflection(.indoorDistance(distance)) = state,
              !isReflectionCommandInFlight else { return }
        distance.kilometers = kilometers
        distance.showsValidationError = false
        state = .reflection(.indoorDistance(distance))
    }

    func saveIndoorDistance() async {
        guard case var .reflection(.indoorDistance(distance)) = state,
              !isReflectionCommandInFlight else { return }
        guard let meters = ManualDistanceParser.meters(fromKilometers: distance.kilometers) else {
            distance.showsValidationError = true
            state = .reflection(.indoorDistance(distance))
            return
        }
        await finalizeReflection(activityID: distance.activityID, manualDistanceMeters: meters)
    }

    func skipIndoorDistance() async {
        guard case let .reflection(.indoorDistance(distance)) = state,
              !isReflectionCommandInFlight else { return }
        await finalizeReflection(activityID: distance.activityID, manualDistanceMeters: nil)
    }

    func showUpdatedArtwork() {
        guard case let .reflection(.enteringArtwork(_, artwork)) = state else { return }
        state = .currentArtwork(artwork)
        artworkBeforeRun = nil
        recorder = nil
        reflectionDraftSaveTask = nil
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
            state = .run(.tracking(.running(
                activeDuration: snapshot.activeDuration,
                distance: snapshot.distance
            )))
        case .paused:
            state = .run(.tracking(.paused(
                activeDuration: snapshot.activeDuration,
                distance: snapshot.distance
            )))
        case .finished:
            break
        }
    }

    private func updateReflectionExpression(
        _ update: (inout ReflectionExpressionState) -> Void
    ) {
        guard case var .reflection(.expression(expression)) = state,
              !isReflectionCommandInFlight,
              let store else { return }
        update(&expression)

        do {
            let draft = try expression.draft
            state = .reflection(.expression(expression))
            enqueueReflectionDraftSave(
                draft,
                activityID: expression.activityID,
                store: store
            )
        } catch {
            state = .blocked
        }
    }

    private func enqueueReflectionDraftSave(
        _ draft: ReflectionDraft,
        activityID: ActivityID,
        store: FurtherStore
    ) {
        let previous = reflectionDraftSaveTask
        reflectionDraftSaveTask = Task { [weak self] in
            await previous?.value
            do {
                try await store.saveReflectionDraft(draft, activityID: activityID)
            } catch {
                guard let self,
                      case let .reflection(.expression(current)) = self.state,
                      current.activityID == activityID else { return }
                self.state = .blocked
            }
        }
    }

    private func finishReflectionExpression(keepingSilence: Bool) async {
        guard case var .reflection(.expression(expression)) = state,
              !isReflectionCommandInFlight,
              let store else { return }
        isReflectionCommandInFlight = true
        defer { isReflectionCommandInFlight = false }

        if keepingSilence {
            expression.feelingColor = nil
            do {
                let draft = try expression.draft
                state = .reflection(.expression(expression))
                enqueueReflectionDraftSave(
                    draft,
                    activityID: expression.activityID,
                    store: store
                )
            } catch {
                state = .blocked
                return
            }
        }

        await reflectionDraftSaveTask?.value
        guard case let .reflection(.expression(current)) = state,
              current.activityID == expression.activityID else { return }
        do {
            try await store.lockExpression(current.draft, activityID: current.activityID)
            if current.environment == .indoor {
                state = .reflection(.indoorDistance(IndoorDistanceState(
                    activityID: current.activityID,
                    kilometers: "",
                    showsValidationError: false
                )))
            } else {
                await finalizeReflection(
                    activityID: current.activityID,
                    manualDistanceMeters: nil,
                    commandAlreadyInFlight: true
                )
            }
        } catch {
            state = .blocked
        }
    }

    private func finalizeReflection(
        activityID: ActivityID,
        manualDistanceMeters: Double?,
        commandAlreadyInFlight: Bool = false
    ) async {
        guard (commandAlreadyInFlight || !isReflectionCommandInFlight), let store else { return }
        if !commandAlreadyInFlight {
            isReflectionCommandInFlight = true
        }
        defer {
            if !commandAlreadyInFlight {
                isReflectionCommandInFlight = false
            }
        }

        do {
            let record = try await store.lockReflection(
                activityID: activityID,
                manualDistanceMeters: manualDistanceMeters,
                finalizedAt: await timeSource.now()
            )
            guard let artwork = try await store.currentArtwork(),
                  artwork.id == record.artworkID else {
                state = .blocked
                return
            }
            let records = try await store.records(for: artwork.id)
            state = .reflection(.enteringArtwork(
                record: record,
                artwork: CurrentArtworkViewState(artwork: artwork, records: records)
            ))
        } catch {
            state = .blocked
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
        case .environmentSelection, .readyIndoor, .readyOutdoor, .countdown, .tracking:
            false
        }
    }

    var hasPersistedSession: Bool {
        switch self {
        case .countdown, .tracking, .endingConfirmation:
            true
        case .environmentSelection, .readyIndoor, .readyOutdoor, .awaitingReflection:
            false
        }
    }

    var hasLiveSession: Bool {
        hasPersistedSession
    }
}

private extension RunFlowViewState {
    var canCancelPreparation: Bool {
        switch self {
        case .environmentSelection, .readyIndoor(isStarting: false),
             .readyOutdoor(_, isStarting: false):
            true
        case .readyIndoor(isStarting: true), .readyOutdoor(_, isStarting: true),
             .countdown, .tracking, .endingConfirmation, .awaitingReflection:
            false
        }
    }
}
