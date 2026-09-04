import Foundation
import XCTest
@testable import Further

final class CollectionStateTests: XCTestCase {
    func testArchivedArtworkKeepsItsVersionedPresentation() throws {
        let artworkID = ArtworkID()
        var artwork = Artwork(
            id: artworkID,
            cycle: .milestone(.tenKilometers),
            visualSeed: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        )
        let startedAt = Date(timeIntervalSince1970: 1_820_000_000)
        let activityID = ActivityID(
            rawValue: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        )
        let assignment = try artwork.beginActivity(
            id: activityID,
            environment: .indoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone
        )
        let record = try DomainTestSamples.record(
            assignment: assignment,
            endedAt: startedAt.addingTimeInterval(60),
            distance: ActivityDistance(meters: 10_000, source: .manualEntry)
        )
        try artwork.include(record, finalizedAt: record.summary.endedAt)
        try artwork.archive(at: record.summary.endedAt.addingTimeInterval(10))
        let entry = try ArtworkCollectionEntry(
            artwork: artwork,
            records: [ActivityRecordIndexEntry(record: record)]
        )

        let first = CollectedArtworkViewState(entry: entry)
        let second = CollectedArtworkViewState(entry: entry)

        XCTAssertEqual(first.presentation, second.presentation)
        XCTAssertEqual(first.presentation.generationVersion, "basic-v1")
        XCTAssertEqual(first.presentation.phase, .completed)
        XCTAssertEqual(first.presentation.marks.map(\.id), [record.id])
        XCTAssertEqual(first.presentation.marks[0].normalizedX, 0.6112108033875029)
        XCTAssertEqual(first.presentation.marks[0].normalizedY, 0.7572542915999084)
        XCTAssertEqual(first.presentation.marks[0].normalizedDiameter, 0.13665064469367513)
    }

    func testCollectionEntryRejectsRecordsOutsideTheArtwork() throws {
        var artwork = Artwork(cycle: .milestone(.tenKilometers))
        let startedAt = Date(timeIntervalSince1970: 1_820_100_000)
        let assignment = try artwork.beginActivity(
            environment: .indoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone
        )
        let record = try DomainTestSamples.record(
            assignment: assignment,
            endedAt: startedAt.addingTimeInterval(60),
            distance: ActivityDistance(meters: 10_000, source: .manualEntry)
        )
        try artwork.include(record, finalizedAt: record.summary.endedAt)
        try artwork.archive(at: record.summary.endedAt)

        XCTAssertThrowsError(try ArtworkCollectionEntry(artwork: artwork, records: []))
    }
}
