import Foundation

enum AppRootRoute: Equatable, Sendable {
    case artworkSelection
    case currentArtwork(ArtworkID)
}

struct AppBootstrapNotice: Equatable, Sendable {
    let interruptedActivityCount: Int
    let lockedReflectionCount: Int
}

struct BootstrappedApp: Sendable {
    let store: FurtherStore
    let route: AppRootRoute
    let notice: AppBootstrapNotice?
}

enum AppBootstrapFailure: Error, Equatable, Sendable {
    case dataUnavailable
}

enum AppBootstrapResult: Sendable {
    case ready(BootstrappedApp)
    case blocked(AppBootstrapFailure)
}

struct AppBootstrap: Sendable {
    let containerSource: ModelContainerSource
    let timeSource: any TimeSource

    func start() async -> AppBootstrapResult {
        do {
            let container = try containerSource.open()
            let store = FurtherStore(modelContainer: container)
            let recovery = try await store.recoverForBootstrap(at: await timeSource.now())
            let route = recovery.currentArtwork.map { AppRootRoute.currentArtwork($0.id) }
                ?? .artworkSelection
            let notice: AppBootstrapNotice? = if recovery.interruptedActivityCount > 0
                || recovery.lockedReflectionCount > 0 {
                AppBootstrapNotice(
                    interruptedActivityCount: recovery.interruptedActivityCount,
                    lockedReflectionCount: recovery.lockedReflectionCount
                )
            } else {
                nil
            }
            return .ready(BootstrappedApp(store: store, route: route, notice: notice))
        } catch {
            return .blocked(.dataUnavailable)
        }
    }
}
