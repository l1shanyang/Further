import Foundation

struct ArtworkCollectionEntry: Identifiable, Equatable, Sendable {
    let artwork: Artwork
    let records: [ActivityRecordIndexEntry]

    var id: ArtworkID { artwork.id }

    init(artwork: Artwork, records: [ActivityRecordIndexEntry]) throws {
        guard case .archived = artwork.state,
              artwork.activityIDs == records.map(\.id) else {
            throw DomainValidationError.invalidArtworkState
        }
        self.artwork = artwork
        self.records = records
    }
}
