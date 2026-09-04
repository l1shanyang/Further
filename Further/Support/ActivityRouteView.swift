import MapKit
import SwiftUI

struct ActivityRouteView: View {
    let record: SharedActivityRecordV1

    static func hasDrawableRoute(_ record: SharedActivityRecordV1) -> Bool {
        segments(for: record).isEmpty == false
    }

    var body: some View {
        let segments = Self.segments(for: record)
        if !segments.isEmpty {
            Map(initialPosition: .region(Self.region(for: segments))) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    MapPolyline(coordinates: segment)
                        .stroke(.blue, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .allowsHitTesting(false)
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .accessibilityIdentifier("record.route")
        }
    }

    private static func segments(for record: SharedActivityRecordV1) -> [[CLLocationCoordinate2D]] {
        var result: [[CLLocationCoordinate2D]] = []
        var current: [CLLocationCoordinate2D] = []
        var previousDate: Date?

        for sample in record.routeSamples {
            guard sample.quality == .accepted else {
                if current.count >= 2 { result.append(current) }
                current = []
                previousDate = nil
                continue
            }
            let crossesGap = previousDate.map {
                sample.measuredAt.timeIntervalSince($0) > LocationRouteAccumulator.maximumSegmentGap
            } ?? false
            let crossesPause = previousDate.map { previous in
                record.events.contains { $0.occurredAt > previous && $0.occurredAt <= sample.measuredAt }
            } ?? false
            if crossesGap || crossesPause {
                if current.count >= 2 { result.append(current) }
                current = []
            }
            current.append(CLLocationCoordinate2D(latitude: sample.latitude, longitude: sample.longitude))
            previousDate = sample.measuredAt
        }
        if current.count >= 2 { result.append(current) }
        return result
    }

    private static func region(for segments: [[CLLocationCoordinate2D]]) -> MKCoordinateRegion {
        let coordinates = segments.flatMap { $0 }
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (latitudes.min()! + latitudes.max()!) / 2,
                longitude: (longitudes.min()! + longitudes.max()!) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.002, (latitudes.max()! - latitudes.min()!) * 1.4),
                longitudeDelta: max(0.002, (longitudes.max()! - longitudes.min()!) * 1.4)
            )
        )
    }
}
