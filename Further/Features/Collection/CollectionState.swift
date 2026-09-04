import Foundation

struct CollectedArtworkViewState: Identifiable, Equatable, Sendable {
    let entry: ArtworkCollectionEntry
    let presentation: BasicArtworkDescription

    var id: ArtworkID { entry.id }

    init(entry: ArtworkCollectionEntry) {
        self.entry = entry
        presentation = BasicArtworkRenderer.render(
            artwork: entry.artwork,
            entries: entry.records
        )
    }
}

struct CollectionViewState: Equatable, Sendable {
    let artworks: [CollectedArtworkViewState]

    init(entries: [ArtworkCollectionEntry]) {
        artworks = entries.map(CollectedArtworkViewState.init)
    }
}

enum CollectionFlowState: Equatable, Sendable {
    case list(CollectionViewState)
    case detail(CollectedArtworkViewState)
}
