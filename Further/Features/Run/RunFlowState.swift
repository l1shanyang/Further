import Foundation

enum ActiveRunViewState: Equatable, Sendable {
    case running(activeDuration: TimeInterval, distance: ActivityDistance?)
    case paused(activeDuration: TimeInterval, distance: ActivityDistance?)

    var activeDuration: TimeInterval {
        switch self {
        case let .running(value, _), let .paused(value, _): value
        }
    }

    var distance: ActivityDistance? {
        switch self {
        case let .running(_, value), let .paused(_, value): value
        }
    }
}

enum RunFlowViewState: Equatable, Sendable {
    case environmentSelection
    case readyIndoor(isStarting: Bool)
    case readyOutdoor(authorization: LocationAuthorizationState, isStarting: Bool)
    case countdown(remainingSeconds: Int)
    case tracking(ActiveRunViewState)
    case endingConfirmation(previous: ActiveRunViewState)
    case awaitingReflection(activityID: ActivityID)
}
