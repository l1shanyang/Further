import Foundation
import XCTest
@testable import Further

final class BasicArtworkRendererTests: XCTestCase {
    func testBlankArtworkContainsNoFabricatedMarks() {
        let artwork = Artwork(
            cycle: .milestone(.tenKilometers),
            visualSeed: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        )

        let description = BasicArtworkRenderer.render(artwork: artwork, records: [])

        XCTAssertEqual(description.phase, .blank)
        XCTAssertEqual(description.generationVersion, "basic-v1")
        XCTAssertTrue(description.marks.isEmpty)
    }

    func testSameSnapshotProducesSameArtworkDescription() throws {
        var artwork = Artwork(
            cycle: .milestone(.tenKilometers),
            visualSeed: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        )
        let startedAt = Date(timeIntervalSince1970: 1_810_100_000)
        let assignment = try artwork.beginActivity(
            environment: .indoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone
        )
        let record = try DomainTestSamples.record(
            assignment: assignment,
            endedAt: startedAt.addingTimeInterval(60)
        )
        try artwork.include(record, finalizedAt: record.summary.endedAt)

        let first = BasicArtworkRenderer.render(artwork: artwork, records: [record])
        let second = BasicArtworkRenderer.render(artwork: artwork, records: [record])

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.phase, .accumulating)
        XCTAssertEqual(first.marks.count, 1)
        XCTAssertEqual(first.marks.first?.color, record.expression.recordColor)
    }

    func testCompletedArtworkHasCompletedPresentationWithoutChangingMarks() throws {
        var artwork = Artwork(cycle: .milestone(.tenKilometers))
        let startedAt = Date(timeIntervalSince1970: 1_810_200_000)
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

        let description = BasicArtworkRenderer.render(artwork: artwork, records: [record])

        XCTAssertEqual(description.phase, .completed)
        XCTAssertEqual(description.marks.count, 1)
    }
}
