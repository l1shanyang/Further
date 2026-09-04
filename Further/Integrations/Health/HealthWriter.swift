import Foundation

enum HealthAuthorizationState: String, Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case unavailable
}

struct HealthWriteReceipt: Equatable, Sendable {
    let workoutUUID: UUID
    let routeUUID: UUID?
}

protocol HealthWriter: Sendable {
    func authorizationState() async -> HealthAuthorizationState
    func requestAuthorization() async -> HealthAuthorizationState
    func write(_ record: SharedActivityRecordV1) async throws -> HealthWriteReceipt
}

actor UnavailableHealthWriter: HealthWriter {
    func authorizationState() -> HealthAuthorizationState { .unavailable }
    func requestAuthorization() -> HealthAuthorizationState { .unavailable }

    func write(_ record: SharedActivityRecordV1) throws -> HealthWriteReceipt {
        throw HealthWriterError.unavailable
    }
}

enum HealthWriterError: Error, Equatable {
    case unavailable
    case missingWorkoutResult
    case missingRouteResult
}
