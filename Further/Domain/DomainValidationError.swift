import Foundation

enum DomainValidationError: Error, Equatable {
    case invalidColorComponent
    case invalidCoordinate
    case invalidDateRange
    case invalidDistance
    case invalidDuration
    case inconsistentDurations
    case invalidActivityEvents
    case invalidExpressionForLifecycle
    case invalidTimeZone
    case unsupportedSchemaVersion(Int)
    case artworkNotAcceptingActivities
    case activityAlreadyInProgress
    case activityNotAssigned
    case activityAlreadyFinalized
    case activityBelongsToAnotherArtwork
    case invalidArtworkState
}
