import Foundation

struct SettingsViewState: Equatable, Sendable {
    var distanceUnit: DistanceUnit
    var locationAuthorization: LocationAuthorizationState
    var healthAuthorization: HealthAuthorizationState
    var canRequestHealthAuthorization: Bool
    var isRequestingHealthAuthorization: Bool
}
