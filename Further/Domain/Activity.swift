import Foundation

enum RunningEnvironment: String, Codable, Equatable, Sendable {
    case indoor
    case outdoor
}

enum TechnicalInterruptionReason: String, Codable, Equatable, Sendable {
    case appTermination
    case systemTermination
    case deviceFailure
    case unknownTechnicalFailure
}

enum ActivityLifecycle: Codable, Equatable, Sendable {
    case endedNormally
    case technicalInterruption(TechnicalInterruptionReason)

    var isNormalEnd: Bool {
        if case .endedNormally = self {
            return true
        }

        return false
    }
}

enum ActivityEventKind: String, Codable, Equatable, Sendable {
    case paused
    case resumed
}

struct ActivityEvent: Codable, Equatable, Sendable {
    let kind: ActivityEventKind
    let occurredAt: Date
}

enum DistanceSource: Codable, Equatable, Sendable {
    case locationDerived(ruleVersion: String)
    case manualEntry
    case externalDevice(sourceIdentifier: String)
}

struct ActivityDistance: Codable, Equatable, Sendable {
    let meters: Double
    let source: DistanceSource

    init(meters: Double, source: DistanceSource) throws {
        self.meters = meters
        self.source = source
        try validate()
    }

    func validate() throws {
        guard meters.isFinite, meters >= 0 else {
            throw DomainValidationError.invalidDistance
        }
    }
}

enum RouteSampleQuality: String, Codable, Equatable, Sendable {
    case accepted
    case rejected
}

struct RouteSample: Codable, Equatable, Sendable {
    let measuredAt: Date
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double
    let horizontalAccuracyMeters: Double
    let verticalAccuracyMeters: Double
    let quality: RouteSampleQuality
    let qualityRuleVersion: String

    init(
        measuredAt: Date,
        latitude: Double,
        longitude: Double,
        altitudeMeters: Double,
        horizontalAccuracyMeters: Double,
        verticalAccuracyMeters: Double,
        quality: RouteSampleQuality,
        qualityRuleVersion: String
    ) throws {
        self.measuredAt = measuredAt
        self.latitude = latitude
        self.longitude = longitude
        self.altitudeMeters = altitudeMeters
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.verticalAccuracyMeters = verticalAccuracyMeters
        self.quality = quality
        self.qualityRuleVersion = qualityRuleVersion
        try validate()
    }

    func validate() throws {
        guard latitude.isFinite,
              longitude.isFinite,
              (-90 ... 90).contains(latitude),
              (-180 ... 180).contains(longitude),
              altitudeMeters.isFinite,
              horizontalAccuracyMeters.isFinite,
              verticalAccuracyMeters.isFinite else {
            throw DomainValidationError.invalidCoordinate
        }
    }
}

struct ActivitySummary: Codable, Equatable, Sendable {
    let startedAt: Date
    let endedAt: Date
    let startTimeZoneIdentifier: String
    let activeDuration: TimeInterval
    let pausedDuration: TimeInterval
    let distance: ActivityDistance?

    init(
        startedAt: Date,
        endedAt: Date,
        startTimeZoneIdentifier: String,
        activeDuration: TimeInterval,
        pausedDuration: TimeInterval,
        distance: ActivityDistance?
    ) throws {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.startTimeZoneIdentifier = startTimeZoneIdentifier
        self.activeDuration = activeDuration
        self.pausedDuration = pausedDuration
        self.distance = distance
        try validate()
    }

    func validate() throws {
        guard endedAt >= startedAt else {
            throw DomainValidationError.invalidDateRange
        }
        guard TimeZone(identifier: startTimeZoneIdentifier) != nil else {
            throw DomainValidationError.invalidTimeZone
        }
        guard activeDuration.isFinite,
              pausedDuration.isFinite,
              activeDuration >= 0,
              pausedDuration >= 0 else {
            throw DomainValidationError.invalidDuration
        }

        let elapsedDuration = endedAt.timeIntervalSince(startedAt)
        guard abs((activeDuration + pausedDuration) - elapsedDuration) < 0.001 else {
            throw DomainValidationError.inconsistentDurations
        }
        try distance?.validate()
    }

    var elapsedDuration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }

    var paceSecondsPerKilometer: TimeInterval? {
        guard let distance, distance.meters > 0, activeDuration > 0 else {
            return nil
        }

        return activeDuration / (distance.meters / 1_000)
    }
}

struct ActivityOrigin: Codable, Equatable, Sendable {
    let productIdentifier: String
    let productVersion: String
    let deviceModel: String?
    let operatingSystemVersion: String?
}
