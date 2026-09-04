@preconcurrency import CoreLocation
@preconcurrency import HealthKit
import Foundation

actor HealthKitWriter: HealthWriter {
    private let store: HKHealthStore

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    func authorizationState() -> HealthAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        return switch store.authorizationStatus(for: HKObjectType.workoutType()) {
        case .notDetermined: .notDetermined
        case .sharingDenied: .denied
        case .sharingAuthorized: .authorized
        @unknown default: .unavailable
        }
    }

    func requestAuthorization() async -> HealthAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        do {
            try await store.requestAuthorization(toShare: Self.writeTypes, read: [])
            return authorizationState()
        } catch {
            return authorizationState()
        }
    }

    func write(_ record: SharedActivityRecordV1) async throws -> HealthWriteReceipt {
        guard authorizationState() == .authorized else {
            throw HealthWriterError.unavailable
        }

        if let workout = try await existingWorkout(for: record.id) {
            let routeUUID = try await ensureRoute(for: record, workout: workout)
            return HealthWriteReceipt(workoutUUID: workout.uuid, routeUUID: routeUUID)
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = record.environment == .indoor ? .indoor : .outdoor
        let builder = HKWorkoutBuilder(
            healthStore: store,
            configuration: configuration,
            device: nil
        )
        try await builder.beginCollection(at: record.summary.startedAt)
        try await builder.addMetadata(Self.metadata(for: record.id, suffix: "workout"))

        let events = record.events.map {
            HKWorkoutEvent(
                type: $0.kind == .paused ? .pause : .resume,
                dateInterval: DateInterval(start: $0.occurredAt, duration: 0),
                metadata: nil
            )
        }
        if !events.isEmpty {
            try await builder.addWorkoutEvents(events)
        }

        if let distance = record.summary.distance,
           store.authorizationStatus(for: Self.distanceType) == .sharingAuthorized {
            let sample = HKQuantitySample(
                type: Self.distanceType,
                quantity: HKQuantity(unit: .meter(), doubleValue: distance.meters),
                start: record.summary.startedAt,
                end: record.summary.endedAt,
                metadata: Self.metadata(for: record.id, suffix: "distance")
            )
            try await builder.addSamples([sample])
        }

        try await builder.endCollection(at: record.summary.endedAt)
        guard let workout = try await builder.finishWorkout() else {
            throw HealthWriterError.missingWorkoutResult
        }

        let routeUUID = try await ensureRoute(for: record, workout: workout)
        return HealthWriteReceipt(workoutUUID: workout.uuid, routeUUID: routeUUID)
    }

    private static let distanceType = HKQuantityType(.distanceWalkingRunning)
    private static let writeTypes: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        distanceType,
        HKSeriesType.workoutRoute(),
    ]

    private static func metadata(for activityID: ActivityID, suffix: String) -> [String: Any] {
        return [
            HKMetadataKeyExternalUUID: activityID.rawValue.uuidString,
            HKMetadataKeySyncIdentifier: syncIdentifier(for: activityID, suffix: suffix),
            HKMetadataKeySyncVersion: 1,
        ]
    }

    private static func location(_ sample: RouteSample) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: sample.latitude,
                longitude: sample.longitude
            ),
            altitude: sample.altitudeMeters,
            horizontalAccuracy: sample.horizontalAccuracyMeters,
            verticalAccuracy: sample.verticalAccuracyMeters,
            timestamp: sample.measuredAt
        )
    }

    private func existingWorkout(for activityID: ActivityID) async throws -> HKWorkout? {
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeySyncIdentifier,
            allowedValues: [Self.syncIdentifier(for: activityID, suffix: "workout")]
        )
        return try await samples(
            type: HKObjectType.workoutType(),
            predicate: predicate,
            limit: 1
        ).first as? HKWorkout
    }

    private func ensureRoute(
        for record: SharedActivityRecordV1,
        workout: HKWorkout
    ) async throws -> UUID? {
        let acceptedRoute = record.routeSamples.filter { $0.quality == .accepted }
        guard !acceptedRoute.isEmpty,
              store.authorizationStatus(for: HKSeriesType.workoutRoute()) == .sharingAuthorized else {
            return nil
        }
        let existing = try await samples(
            type: HKSeriesType.workoutRoute(),
            predicate: HKQuery.predicateForObjects(from: workout),
            limit: 1
        ).first as? HKWorkoutRoute
        if let existing { return existing.uuid }

        let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: nil)
        try await routeBuilder.insertRouteData(acceptedRoute.map(Self.location))
        let route = try await finishRoute(
            routeBuilder,
            workout: workout,
            metadata: Self.metadata(for: record.id, suffix: "route")
        )
        return route.uuid
    }

    private func samples(
        type: HKSampleType,
        predicate: NSPredicate,
        limit: Int
    ) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            store.execute(query)
        }
    }

    private func finishRoute(
        _ builder: HKWorkoutRouteBuilder,
        workout: HKWorkout,
        metadata: [String: Any]
    ) async throws -> HKWorkoutRoute {
        try await withCheckedThrowingContinuation { continuation in
            builder.finishRoute(with: workout, metadata: metadata) { route, error in
                if let route {
                    continuation.resume(returning: route)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: HealthWriterError.missingRouteResult)
                }
            }
        }
    }

    private static func syncIdentifier(for activityID: ActivityID, suffix: String) -> String {
        "further.\(activityID.rawValue.uuidString.lowercased()).\(suffix)"
    }
}
