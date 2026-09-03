import Foundation
import XCTest
@testable import Further

final class ArtworkTests: XCTestCase {
    func testTimeArtworkStartsWithFirstActivityAndStoresCalendarBoundary() throws {
        let startedAt = Date(timeIntervalSince1970: 1_767_225_600)
        var artwork = Artwork(cycle: .time(.oneMonth))

        _ = try artwork.beginActivity(
            environment: .outdoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone
        )

        guard case let .accumulating(period) = artwork.state else {
            return XCTFail("Expected an accumulating artwork")
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = DomainTestSamples.timeZone
        XCTAssertEqual(period.startedAt, startedAt)
        XCTAssertEqual(period.endsAt, calendar.date(byAdding: .month, value: 1, to: startedAt))
    }

    func testActivityStartedBeforeBoundaryCompletesInsideOriginalArtwork() throws {
        let artworkStartedAt = Date(timeIntervalSince1970: 1_767_225_600)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = DomainTestSamples.timeZone
        let boundary = try XCTUnwrap(calendar.date(byAdding: .month, value: 1, to: artworkStartedAt))
        var artwork = Artwork(cycle: .time(.oneMonth))

        let first = try artwork.beginActivity(
            environment: .outdoor,
            at: artworkStartedAt,
            timeZone: DomainTestSamples.timeZone
        )
        try artwork.include(
            DomainTestSamples.record(
                assignment: first,
                endedAt: artworkStartedAt.addingTimeInterval(600)
            ),
            finalizedAt: artworkStartedAt.addingTimeInterval(601)
        )

        let crossing = try artwork.beginActivity(
            environment: .outdoor,
            at: boundary.addingTimeInterval(-60),
            timeZone: DomainTestSamples.timeZone
        )
        artwork.evaluate(at: boundary.addingTimeInterval(30))
        XCTAssertEqual(artwork.pendingActivityID, crossing.activityID)

        let finalizedAt = boundary.addingTimeInterval(121)
        try artwork.include(
            DomainTestSamples.record(
                assignment: crossing,
                endedAt: boundary.addingTimeInterval(120)
            ),
            finalizedAt: finalizedAt
        )

        guard case let .completed(_, completedAt) = artwork.state else {
            return XCTFail("Expected a completed artwork")
        }
        XCTAssertEqual(completedAt, finalizedAt)
        XCTAssertEqual(artwork.activityIDs, [first.activityID, crossing.activityID])
    }

    func testExpiredTimeArtworkRejectsNewActivity() throws {
        let startedAt = Date(timeIntervalSince1970: 1_767_225_600)
        var artwork = Artwork(cycle: .time(.oneMonth))
        let first = try artwork.beginActivity(
            environment: .indoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone
        )
        try artwork.include(
            DomainTestSamples.record(
                assignment: first,
                endedAt: startedAt.addingTimeInterval(60)
            ),
            finalizedAt: startedAt.addingTimeInterval(61)
        )

        guard case let .accumulating(period) = artwork.state else {
            return XCTFail("Expected an accumulating artwork")
        }
        let boundary = try XCTUnwrap(period.endsAt)

        XCTAssertThrowsError(
            try artwork.beginActivity(
                environment: .outdoor,
                at: boundary,
                timeZone: DomainTestSamples.timeZone
            )
        ) { error in
            XCTAssertEqual(error as? DomainValidationError, .artworkNotAcceptingActivities)
        }
        guard case .completed = artwork.state else {
            return XCTFail("Expected the expired artwork to be completed")
        }
    }

    func testNormalActivityCanCompleteMilestoneArtwork() throws {
        var artwork = Artwork(cycle: .milestone(.tenKilometers))
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let assignment = try artwork.beginActivity(
            environment: .indoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone
        )
        let distance = try ActivityDistance(meters: 10_000, source: .manualEntry)

        try artwork.include(
            DomainTestSamples.record(
                assignment: assignment,
                endedAt: startedAt.addingTimeInterval(3_600),
                distance: distance
            ),
            finalizedAt: startedAt.addingTimeInterval(3_601)
        )

        guard case .completed = artwork.state else {
            return XCTFail("Expected the milestone artwork to be completed")
        }
    }

    func testMissingDistanceDoesNotCompleteMilestoneArtwork() throws {
        var artwork = Artwork(cycle: .milestone(.tenKilometers))
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let assignment = try artwork.beginActivity(
            environment: .outdoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone
        )

        try artwork.include(
            DomainTestSamples.record(
                assignment: assignment,
                endedAt: startedAt.addingTimeInterval(3_600),
                distance: nil
            ),
            finalizedAt: startedAt.addingTimeInterval(3_601)
        )

        guard case .accumulating = artwork.state else {
            return XCTFail("Expected the milestone artwork to keep accumulating")
        }
    }

    func testTechnicalInterruptionCannotCompleteMilestoneArtwork() throws {
        var artwork = Artwork(cycle: .milestone(.tenKilometers))
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let assignment = try artwork.beginActivity(
            environment: .outdoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone
        )
        let distance = try ActivityDistance(
            meters: 12_000,
            source: .locationDerived(ruleVersion: "1")
        )

        try artwork.include(
            DomainTestSamples.record(
                assignment: assignment,
                endedAt: startedAt.addingTimeInterval(3_600),
                lifecycle: .technicalInterruption(.appTermination),
                distance: distance
            ),
            finalizedAt: startedAt.addingTimeInterval(3_601)
        )

        guard case .accumulating = artwork.state else {
            return XCTFail("Expected the interrupted activity not to complete the milestone")
        }
    }
}
