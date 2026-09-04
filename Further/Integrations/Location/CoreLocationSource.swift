@preconcurrency import CoreLocation
import Foundation

@MainActor
final class CoreLocationSource: NSObject, LocationSource, @preconcurrency CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var continuation: AsyncStream<LocationMeasurement>.Continuation?
    private var authorizationContinuations: [CheckedContinuation<LocationAuthorizationState, Never>] = []

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
    }

    func currentAuthorization() -> LocationAuthorizationState {
        guard CLLocationManager.locationServicesEnabled() else { return .unavailable }
        return Self.map(manager.authorizationStatus)
    }

    func requestAuthorization() async -> LocationAuthorizationState {
        let current = currentAuthorization()
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            authorizationContinuations.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
    }

    func startUpdates() -> AsyncStream<LocationMeasurement> {
        stopUpdates()
        guard currentAuthorization().canRecordLocation else {
            return AsyncStream { $0.finish() }
        }

        let stream = AsyncStream<LocationMeasurement> { continuation in
            self.continuation = continuation
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in self?.stopUpdates() }
            }
        }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        return stream
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        continuation?.finish()
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let state = currentAuthorization()
        guard state != .notDetermined else { return }
        let continuations = authorizationContinuations
        authorizationContinuations.removeAll()
        continuations.forEach { $0.resume(returning: state) }
        if !state.canRecordLocation {
            stopUpdates()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            continuation?.yield(LocationMeasurement(
                measuredAt: location.timestamp,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitudeMeters: location.altitude,
                horizontalAccuracyMeters: location.horizontalAccuracy,
                verticalAccuracyMeters: location.verticalAccuracy
            ))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        // A temporary location failure is a gap, not the end of a running session.
    }

    private static func map(_ status: CLAuthorizationStatus) -> LocationAuthorizationState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .authorizedAlways, .authorizedWhenInUse:
            .authorized
        case .denied, .restricted:
            .denied
        @unknown default:
            .unavailable
        }
    }
}
