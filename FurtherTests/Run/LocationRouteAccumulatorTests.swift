import Foundation
import XCTest
@testable import Further

final class LocationRouteAccumulatorTests: XCTestCase {
    func testReliableLocationsAccumulateDistanceAndKeepQualityEvidence() throws {
        let startedAt = Date(timeIntervalSince1970: 1_830_000_000)
        var accumulator = LocationRouteAccumulator()

        try accumulator.record(
            measurement(at: startedAt, latitude: 31.2304, longitude: 121.4737),
            sessionStartedAt: startedAt,
            isActive: true
        )
        try accumulator.record(
            measurement(
                at: startedAt.addingTimeInterval(10),
                latitude: 31.2310,
                longitude: 121.4737
            ),
            sessionStartedAt: startedAt,
            isActive: true
        )

        XCTAssertEqual(accumulator.samples.map(\.quality), [.accepted, .accepted])
        XCTAssertEqual(
            accumulator.samples.map(\.qualityRuleVersion),
            ["location-v1", "location-v1"]
        )
        XCTAssertEqual(accumulator.distance?.meters ?? 0, 66.7, accuracy: 1)
        XCTAssertEqual(
            accumulator.distance?.source,
            .locationDerived(ruleVersion: "location-v1")
        )
    }

    func testPoorAccuracyAndImpossibleSpeedAreRejected() throws {
        let startedAt = Date(timeIntervalSince1970: 1_830_000_000)
        var accumulator = LocationRouteAccumulator()

        try accumulator.record(
            measurement(at: startedAt, latitude: 31, longitude: 121),
            sessionStartedAt: startedAt,
            isActive: true
        )
        try accumulator.record(
            measurement(
                at: startedAt.addingTimeInterval(1),
                latitude: 31.01,
                longitude: 121,
                accuracy: 100
            ),
            sessionStartedAt: startedAt,
            isActive: true
        )
        try accumulator.record(
            measurement(
                at: startedAt.addingTimeInterval(2),
                latitude: 31.01,
                longitude: 121
            ),
            sessionStartedAt: startedAt,
            isActive: true
        )

        XCTAssertEqual(accumulator.samples.map(\.quality), [.accepted, .rejected, .rejected])
        XCTAssertNil(accumulator.distance)
    }

    func testGapAndPauseBreakDoNotInferMissingDistance() throws {
        let startedAt = Date(timeIntervalSince1970: 1_830_000_000)
        var accumulator = LocationRouteAccumulator()
        let points = [31.0, 31.0001, 31.001, 31.0011]
        let offsets: [TimeInterval] = [0, 10, 50, 60]

        for (index, latitude) in points.enumerated() {
            if index == 2 { accumulator.breakSegment() }
            try accumulator.record(
                measurement(
                    at: startedAt.addingTimeInterval(offsets[index]),
                    latitude: latitude,
                    longitude: 121
                ),
                sessionStartedAt: startedAt,
                isActive: true
            )
        }

        XCTAssertEqual(accumulator.samples.map(\.quality), Array(repeating: .accepted, count: 4))
        XCTAssertEqual(accumulator.distance?.meters ?? 0, 22.2, accuracy: 1)
    }

    func testPauseBeforeFirstReliablePointOnlyBreaksThePreviousSegment() throws {
        let startedAt = Date(timeIntervalSince1970: 1_830_000_000)
        var accumulator = LocationRouteAccumulator()
        accumulator.breakSegment()

        try accumulator.record(
            measurement(at: startedAt, latitude: 31, longitude: 121),
            sessionStartedAt: startedAt,
            isActive: true
        )
        try accumulator.record(
            measurement(
                at: startedAt.addingTimeInterval(10),
                latitude: 31.0001,
                longitude: 121
            ),
            sessionStartedAt: startedAt,
            isActive: true
        )

        XCTAssertEqual(accumulator.distance?.meters ?? 0, 11.1, accuracy: 1)
    }

    private func measurement(
        at date: Date,
        latitude: Double,
        longitude: Double,
        accuracy: Double = 5
    ) -> LocationMeasurement {
        LocationMeasurement(
            measuredAt: date,
            latitude: latitude,
            longitude: longitude,
            altitudeMeters: 10,
            horizontalAccuracyMeters: accuracy,
            verticalAccuracyMeters: 8
        )
    }
}
