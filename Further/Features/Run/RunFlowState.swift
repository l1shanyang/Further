import Foundation

enum ActiveRunViewState: Equatable, Sendable {
    case running(activeDuration: TimeInterval)
    case paused(activeDuration: TimeInterval)

    var activeDuration: TimeInterval {
        switch self {
        case let .running(value), let .paused(value): value
        }
    }
}

enum RunFlowViewState: Equatable, Sendable {
    case environmentSelection
    case readyIndoor(isStarting: Bool)
    case countdown(remainingSeconds: Int)
    case tracking(ActiveRunViewState)
    case endingConfirmation(previous: ActiveRunViewState)
    case awaitingReflection(activityID: ActivityID)
}
