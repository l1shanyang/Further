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
    case blocked
}

@MainActor
@Observable
final class AppRootModel {
    private(set) var state: AppRootState = .loading
    private(set) var recoveryNotice: AppBootstrapNotice?

    private let bootstrap: AppBootstrap
    private let timeSource: any TimeSource
    private var store: FurtherStore?
    private var isStarting = false

    init(bootstrap: AppBootstrap, timeSource: any TimeSource) {
        self.bootstrap = bootstrap
        self.timeSource = timeSource
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
}
