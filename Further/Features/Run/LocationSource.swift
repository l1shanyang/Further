import Foundation

enum LocationAuthorizationState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case unavailable

    var canRecordLocation: Bool {
        self == .authorized
    }
}

struct LocationMeasurement: Equatable, Sendable {
    let measuredAt: Date
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double
    let horizontalAccuracyMeters: Double
    let verticalAccuracyMeters: Double
}

@MainActor
protocol LocationSource: Sendable {
    func currentAuthorization() -> LocationAuthorizationState
    func requestAuthorization() async -> LocationAuthorizationState
    func startUpdates() -> AsyncStream<LocationMeasurement>
    func stopUpdates()
}

@MainActor
final class UnavailableLocationSource: LocationSource {
    private let authorization: LocationAuthorizationState

    init(authorization: LocationAuthorizationState = .unavailable) {
        self.authorization = authorization
    }

    func currentAuthorization() -> LocationAuthorizationState {
        authorization
    }

    func requestAuthorization() async -> LocationAuthorizationState {
        authorization
    }

    func startUpdates() -> AsyncStream<LocationMeasurement> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func stopUpdates() {}
}
