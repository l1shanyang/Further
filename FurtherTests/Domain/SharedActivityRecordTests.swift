import Foundation
import XCTest
@testable import Further

final class SharedActivityRecordTests: XCTestCase {
    func testVersionedRecordRoundTripsWithoutChangingSemantics() throws {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000.123_456)
        var artwork = Artwork(cycle: .time(.threeMonths))
        let assignment = try artwork.beginActivity(
            environment: .outdoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone
        )
        let distance = try ActivityDistance(
            meters: 5_000,
            source: .locationDerived(ruleVersion: "distance-1")
        )
        let routeSample = try RouteSample(
            measuredAt: startedAt.addingTimeInterval(10),
            latitude: 31.2304,
            longitude: 121.4737,
            altitudeMeters: 8,
            horizontalAccuracyMeters: 5,
            verticalAccuracyMeters: 7,
            quality: .accepted,
            qualityRuleVersion: "location-quality-1"
        )
        let expression = RecordExpression.feeling(
            color: FeelingColor(
                identifier: "feeling-blue",
                paletteVersion: "1",
                value: try RecordColorValue(red: 0.1, green: 0.2, blue: 0.8)
            ),
            note: "quiet river"
        )
        let record = try DomainTestSamples.record(
            assignment: assignment,
            endedAt: startedAt.addingTimeInterval(1_860),
            distance: distance,
            pausedDuration: 60,
            events: [
                ActivityEvent(kind: .paused, occurredAt: startedAt.addingTimeInterval(600)),
                ActivityEvent(kind: .resumed, occurredAt: startedAt.addingTimeInterval(660)),
            ],
            routeSamples: [routeSample],
            expression: expression
        )

        let data = try SharedActivityRecordCodec.encode(record)
        let decoded = try SharedActivityRecordCodec.decode(data)

        XCTAssertEqual(decoded, record)
        XCTAssertEqual(decoded.schemaVersion, 1)
    }

    func testDecoderIgnoresUnknownFutureFieldsWithinV1() throws {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        var artwork = Artwork(cycle: .milestone(.halfMarathon))
        let assignment = try artwork.beginActivity(
            environment: .indoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone
        )
        let record = try DomainTestSamples.record(
            assignment: assignment,
            endedAt: startedAt.addingTimeInterval(60)
        )
        let encoded = try SharedActivityRecordCodec.encode(record)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object["futureField"] = ["value": true]
        let dataWithUnknownField = try JSONSerialization.data(withJSONObject: object)

        XCTAssertEqual(
            try SharedActivityRecordCodec.decode(dataWithUnknownField),
            record
        )
    }

    func testDecoderRejectsUnsupportedSchemaVersion() throws {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        var artwork = Artwork(cycle: .milestone(.marathon))
        let assignment = try artwork.beginActivity(
            environment: .indoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone
        )
        let encoded = try SharedActivityRecordCodec.encode(
            DomainTestSamples.record(
                assignment: assignment,
                endedAt: startedAt.addingTimeInterval(60)
            )
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object["schemaVersion"] = 2
        let unsupportedData = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try SharedActivityRecordCodec.decode(unsupportedData)) { error in
            XCTAssertEqual(
                error as? DomainValidationError,
                .unsupportedSchemaVersion(2)
            )
        }
    }

    func testDecoderRejectsDistanceThatBreaksDomainInvariant() throws {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        var artwork = Artwork(cycle: .milestone(.tenKilometers))
        let assignment = try artwork.beginActivity(
            environment: .indoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone
        )
        let record = try DomainTestSamples.record(
            assignment: assignment,
            endedAt: startedAt.addingTimeInterval(60),
            distance: ActivityDistance(meters: 100, source: .manualEntry)
        )
        let encoded = try SharedActivityRecordCodec.encode(record)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var summary = try XCTUnwrap(object["summary"] as? [String: Any])
        var distance = try XCTUnwrap(summary["distance"] as? [String: Any])
        distance["meters"] = -100
        summary["distance"] = distance
        object["summary"] = summary
        let invalidData = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try SharedActivityRecordCodec.decode(invalidData)) { error in
            XCTAssertEqual(error as? DomainValidationError, .invalidDistance)
        }
    }

    func testTechnicalInterruptionRequiresSilenceExpression() throws {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        var artwork = Artwork(cycle: .milestone(.tenKilometers))
        let assignment = try artwork.beginActivity(
            environment: .outdoor,
            at: startedAt,
            timeZone: DomainTestSamples.timeZone
        )
        let feeling = RecordExpression.feeling(
            color: FeelingColor(
                identifier: "feeling-red",
                paletteVersion: "1",
                value: try RecordColorValue(red: 0.8, green: 0.1, blue: 0.1)
            ),
            note: nil
        )

        XCTAssertThrowsError(
            try DomainTestSamples.record(
                assignment: assignment,
                endedAt: startedAt.addingTimeInterval(60),
                lifecycle: .technicalInterruption(.systemTermination),
                expression: feeling
            )
        ) { error in
            XCTAssertEqual(
                error as? DomainValidationError,
                .invalidExpressionForLifecycle
            )
        }
    }
}
