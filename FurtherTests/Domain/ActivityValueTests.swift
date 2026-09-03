import Foundation
import XCTest
@testable import Further

final class ActivityValueTests: XCTestCase {
    func testMissingDistanceIsDifferentFromZeroDistance() throws {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let endedAt = startedAt.addingTimeInterval(600)

        let missingDistance = try ActivitySummary(
            startedAt: startedAt,
            endedAt: endedAt,
            startTimeZoneIdentifier: DomainTestSamples.timeZone.identifier,
            activeDuration: 600,
            pausedDuration: 0,
            distance: nil
        )
        let zeroDistance = try ActivitySummary(
            startedAt: startedAt,
            endedAt: endedAt,
            startTimeZoneIdentifier: DomainTestSamples.timeZone.identifier,
            activeDuration: 600,
            pausedDuration: 0,
            distance: ActivityDistance(meters: 0, source: .manualEntry)
        )

        XCTAssertNil(missingDistance.distance)
        XCTAssertEqual(zeroDistance.distance?.meters, 0)
        XCTAssertNotEqual(missingDistance, zeroDistance)
        XCTAssertNil(missingDistance.paceSecondsPerKilometer)
        XCTAssertNil(zeroDistance.paceSecondsPerKilometer)
    }

    func testSummaryRejectsDurationsThatDoNotMatchElapsedTime() {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertThrowsError(
            try ActivitySummary(
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(600),
                startTimeZoneIdentifier: DomainTestSamples.timeZone.identifier,
                activeDuration: 500,
                pausedDuration: 50,
                distance: nil
            )
        ) { error in
            XCTAssertEqual(error as? DomainValidationError, .inconsistentDurations)
        }
    }

    func testPaceUsesActiveDurationAndReliableDistance() throws {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let summary = try ActivitySummary(
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(1_860),
            startTimeZoneIdentifier: DomainTestSamples.timeZone.identifier,
            activeDuration: 1_800,
            pausedDuration: 60,
            distance: ActivityDistance(
                meters: 5_000,
                source: .locationDerived(ruleVersion: "1")
            )
        )

        XCTAssertEqual(summary.elapsedDuration, 1_860)
        XCTAssertEqual(summary.paceSecondsPerKilometer, 360)
    }

    func testRouteSampleKeepsMeasurementAndQualityDecision() throws {
        let sample = try RouteSample(
            measuredAt: Date(timeIntervalSince1970: 1_800_000_000),
            latitude: 31.2304,
            longitude: 121.4737,
            altitudeMeters: 8,
            horizontalAccuracyMeters: 5,
            verticalAccuracyMeters: 7,
            quality: .rejected,
            qualityRuleVersion: "1"
        )

        XCTAssertEqual(sample.quality, .rejected)
        XCTAssertEqual(sample.qualityRuleVersion, "1")
        XCTAssertEqual(sample.latitude, 31.2304)
    }
}
