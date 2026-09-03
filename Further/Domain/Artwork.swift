import Foundation

enum TimeArtworkDuration: String, Codable, Equatable, Sendable {
    case oneMonth
    case threeMonths
    case oneYear

    fileprivate func endDate(from startDate: Date, timeZone: TimeZone) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let component: DateComponents = switch self {
        case .oneMonth:
            DateComponents(month: 1)
        case .threeMonths:
            DateComponents(month: 3)
        case .oneYear:
            DateComponents(year: 1)
        }

        guard let endDate = calendar.date(byAdding: component, to: startDate) else {
            throw DomainValidationError.invalidDateRange
        }

        return endDate
    }
}

enum RunningMilestone: String, Codable, Equatable, Sendable {
    case tenKilometers
    case halfMarathon
    case marathon

    var distanceMeters: Double {
        switch self {
        case .tenKilometers:
            10_000
        case .halfMarathon:
            21_097.5
        case .marathon:
            42_195
        }
    }
}

enum ArtworkCycle: Codable, Equatable, Sendable {
    case time(TimeArtworkDuration)
    case milestone(RunningMilestone)
}

struct ArtworkPeriod: Codable, Equatable, Sendable {
    let startedAt: Date
    let startTimeZoneIdentifier: String
    let endsAt: Date?
}

enum ArtworkState: Codable, Equatable, Sendable {
    case blank
    case accumulating(ArtworkPeriod)
    case completed(period: ArtworkPeriod, completedAt: Date)
    case archived(period: ArtworkPeriod, completedAt: Date, archivedAt: Date)
}

struct ActivityAssignment: Equatable, Sendable {
    let activityID: ActivityID
    let artworkID: ArtworkID
    let environment: RunningEnvironment
    let startedAt: Date
    let startTimeZoneIdentifier: String
}

struct Artwork: Codable, Equatable, Sendable {
    let id: ArtworkID
    let cycle: ArtworkCycle
    private(set) var state: ArtworkState
    private(set) var activityIDs: [ActivityID]
    private(set) var pendingActivityID: ActivityID?

    init(id: ArtworkID = ArtworkID(), cycle: ArtworkCycle) {
        self.id = id
        self.cycle = cycle
        state = .blank
        activityIDs = []
        pendingActivityID = nil
    }

    mutating func beginActivity(
        id activityID: ActivityID = ActivityID(),
        environment: RunningEnvironment,
        at startedAt: Date,
        timeZone: TimeZone
    ) throws -> ActivityAssignment {
        guard pendingActivityID == nil else {
            throw DomainValidationError.activityAlreadyInProgress
        }

        switch state {
        case .blank:
            state = .accumulating(try makePeriod(startedAt: startedAt, timeZone: timeZone))
        case let .accumulating(period):
            if let endsAt = period.endsAt, startedAt >= endsAt {
                state = .completed(period: period, completedAt: endsAt)
                throw DomainValidationError.artworkNotAcceptingActivities
            }
        case .completed, .archived:
            throw DomainValidationError.artworkNotAcceptingActivities
        }

        activityIDs.append(activityID)
        pendingActivityID = activityID

        return ActivityAssignment(
            activityID: activityID,
            artworkID: id,
            environment: environment,
            startedAt: startedAt,
            startTimeZoneIdentifier: timeZone.identifier
        )
    }

    mutating func include(_ record: SharedActivityRecordV1, finalizedAt: Date) throws {
        guard record.artworkID == id else {
            throw DomainValidationError.activityBelongsToAnotherArtwork
        }
        guard pendingActivityID != nil else {
            if activityIDs.contains(record.id) {
                throw DomainValidationError.activityAlreadyFinalized
            }

            throw DomainValidationError.activityNotAssigned
        }
        guard pendingActivityID == record.id else {
            throw DomainValidationError.activityNotAssigned
        }

        pendingActivityID = nil

        guard case let .accumulating(period) = state else {
            throw DomainValidationError.artworkNotAcceptingActivities
        }

        switch cycle {
        case .time:
            if let endsAt = period.endsAt, record.summary.endedAt >= endsAt {
                state = .completed(period: period, completedAt: finalizedAt)
            }
        case let .milestone(milestone):
            if record.lifecycle.isNormalEnd,
               let distance = record.summary.distance,
               distance.meters >= milestone.distanceMeters {
                state = .completed(period: period, completedAt: finalizedAt)
            }
        }
    }

    mutating func evaluate(at date: Date) {
        guard pendingActivityID == nil,
              case let .accumulating(period) = state,
              let endsAt = period.endsAt,
              date >= endsAt else {
            return
        }

        state = .completed(period: period, completedAt: endsAt)
    }

    mutating func archive(at archivedAt: Date) throws {
        guard pendingActivityID == nil,
              case let .completed(period, completedAt) = state else {
            throw DomainValidationError.artworkNotAcceptingActivities
        }

        state = .archived(
            period: period,
            completedAt: completedAt,
            archivedAt: archivedAt
        )
    }

    private func makePeriod(startedAt: Date, timeZone: TimeZone) throws -> ArtworkPeriod {
        let endsAt: Date? = switch cycle {
        case let .time(duration):
            try duration.endDate(from: startedAt, timeZone: timeZone)
        case .milestone:
            nil
        }

        return ArtworkPeriod(
            startedAt: startedAt,
            startTimeZoneIdentifier: timeZone.identifier,
            endsAt: endsAt
        )
    }
}
