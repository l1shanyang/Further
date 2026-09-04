import Foundation

struct LocationRouteAccumulator: Sendable {
    static let qualityRuleVersion = "location-v1"
    static let maximumHorizontalAccuracyMeters = 50.0
    static let maximumSegmentGap: TimeInterval = 30
    static let maximumPlausibleSpeedMetersPerSecond = 12.0

    private(set) var samples: [RouteSample] = []
    private(set) var distanceMeters = 0.0
    private(set) var hasReliableSegment = false

    private var lastMeasurementAt: Date?
    private var lastAcceptedMeasurement: LocationMeasurement?

    var distance: ActivityDistance? {
        guard hasReliableSegment else { return nil }
        return try? ActivityDistance(
            meters: distanceMeters,
            source: .locationDerived(ruleVersion: Self.qualityRuleVersion)
        )
    }

    mutating func breakSegment() {
        lastAcceptedMeasurement = nil
    }

    mutating func record(
        _ measurement: LocationMeasurement,
        sessionStartedAt: Date,
        isActive: Bool
    ) throws {
        let isChronological = lastMeasurementAt.map { measurement.measuredAt > $0 } ?? true
        let hasValidAccuracy = measurement.horizontalAccuracyMeters >= 0
            && measurement.horizontalAccuracyMeters <= Self.maximumHorizontalAccuracyMeters
        let isFresh = measurement.measuredAt >= sessionStartedAt
        var quality: RouteSampleQuality = .rejected

        if isActive, isChronological, hasValidAccuracy, isFresh {
            quality = .accepted
            if let previous = lastAcceptedMeasurement {
                let interval = measurement.measuredAt.timeIntervalSince(previous.measuredAt)
                if interval > Self.maximumSegmentGap {
                } else {
                    let segmentDistance = Self.distance(from: previous, to: measurement)
                    if interval > 0,
                       segmentDistance / interval <= Self.maximumPlausibleSpeedMetersPerSecond {
                        distanceMeters += segmentDistance
                        hasReliableSegment = true
                    } else {
                        quality = .rejected
                    }
                }
            }
            if quality == .accepted {
                lastAcceptedMeasurement = measurement
            }
        }

        if isChronological {
            lastMeasurementAt = measurement.measuredAt
        }
        samples.append(try RouteSample(
            measuredAt: measurement.measuredAt,
            latitude: measurement.latitude,
            longitude: measurement.longitude,
            altitudeMeters: measurement.altitudeMeters,
            horizontalAccuracyMeters: measurement.horizontalAccuracyMeters,
            verticalAccuracyMeters: measurement.verticalAccuracyMeters,
            quality: quality,
            qualityRuleVersion: Self.qualityRuleVersion
        ))
    }

    private static func distance(
        from start: LocationMeasurement,
        to end: LocationMeasurement
    ) -> Double {
        let earthRadiusMeters = 6_371_000.0
        let startLatitude = start.latitude * .pi / 180
        let endLatitude = end.latitude * .pi / 180
        let latitudeDelta = (end.latitude - start.latitude) * .pi / 180
        let longitudeDelta = (end.longitude - start.longitude) * .pi / 180
        let value = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(startLatitude) * cos(endLatitude)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        return earthRadiusMeters * 2 * atan2(sqrt(value), sqrt(1 - value))
    }
}
