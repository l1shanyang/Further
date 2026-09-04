import Foundation

enum ArtworkPresentationPhase: Equatable, Sendable {
    case blank
    case accumulating
    case completed
}

struct ArtworkMarkDescription: Equatable, Identifiable, Sendable {
    let id: ActivityID
    let color: RecordColorValue
    let normalizedX: Double
    let normalizedY: Double
    let normalizedDiameter: Double
}

struct BasicArtworkDescription: Equatable, Sendable {
    let generationVersion: String
    let phase: ArtworkPresentationPhase
    let marks: [ArtworkMarkDescription]
}

enum BasicArtworkRenderer {
    static func render(
        artwork: Artwork,
        records: [SharedActivityRecordV1]
    ) -> BasicArtworkDescription {
        render(
            artwork: artwork,
            entries: records.map { ActivityRecordIndexEntry(record: $0) }
        )
    }

    static func render(
        artwork: Artwork,
        entries: [ActivityRecordIndexEntry]
    ) -> BasicArtworkDescription {
        let recordsByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        let marks = artwork.activityIDs.compactMap { activityID -> ArtworkMarkDescription? in
            guard let record = recordsByID[activityID] else { return nil }
            let seed = "\(artwork.visualSeed.uuidString):\(activityID.rawValue.uuidString)"
            return ArtworkMarkDescription(
                id: activityID,
                color: record.expression.recordColor,
                normalizedX: 0.14 + normalizedValue(seed, salt: 1) * 0.72,
                normalizedY: 0.14 + normalizedValue(seed, salt: 2) * 0.72,
                normalizedDiameter: 0.12 + normalizedValue(seed, salt: 3) * 0.16
            )
        }

        return BasicArtworkDescription(
            generationVersion: artwork.visualGenerationVersion,
            phase: phase(for: artwork.state),
            marks: marks
        )
    }

    private static func phase(for state: ArtworkState) -> ArtworkPresentationPhase {
        switch state {
        case .blank:
            .blank
        case .accumulating:
            .accumulating
        case .completed, .archived:
            .completed
        }
    }

    private static func normalizedValue(_ value: String, salt: UInt64) -> Double {
        var hash = 14_695_981_039_346_656_037 ^ salt
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Double(hash & 0xFFFF) / Double(UInt16.max)
    }
}
