import MapKit
import SwiftUI

struct ReflectionFlowView: View {
    let state: ReflectionFlowViewState
    let isCommandInFlight: Bool
    let onSelectColor: (FeelingColor) -> Void
    let onChangeNote: (String) -> Void
    let onFinishExpression: () -> Void
    let onKeepSilence: () -> Void
    let onChangeDistance: (String) -> Void
    let onSaveDistance: () -> Void
    let onSkipDistance: () -> Void
    let onShowArtwork: () -> Void

    var body: some View {
        content
            .padding(24)
            .navigationBarBackButtonHidden()
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case let .expression(expression):
            expressionView(expression)
        case let .indoorDistance(distance):
            distanceView(distance)
        case let .enteringArtwork(record, artwork):
            enteringArtworkView(record: record, artwork: artwork)
        }
    }

    private func expressionView(_ expression: ReflectionExpressionState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppText.howDidItFeel)
                        .font(.largeTitle.bold())
                    Text(AppText.chooseFeelingColor)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3),
                    spacing: 14
                ) {
                    ForEach(Array(FeelingColorOption.all.enumerated()), id: \.element.id) { item in
                        let (index, option) = item
                        Button {
                            onSelectColor(option.color)
                        } label: {
                            Circle()
                                .fill(Color(option.color.value))
                                .overlay {
                                    if expression.feelingColor == option.color {
                                        Circle()
                                            .strokeBorder(.primary, lineWidth: 3)
                                            .padding(3)
                                    }
                                }
                                .frame(width: 68, height: 68)
                        }
                        .buttonStyle(.plain)
                        .disabled(isCommandInFlight)
                        .accessibilityLabel(AppText.feelingColor(index + 1))
                        .accessibilityIdentifier("reflection.color.\(index + 1)")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(AppText.shortNote)
                        .font(.headline)
                    TextField(
                        AppText.shortNotePlaceholder,
                        text: Binding(
                            get: { expression.note },
                            set: { value in onChangeNote(value) }
                        ),
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3)
                    .disabled(isCommandInFlight)
                    .accessibilityIdentifier("reflection.note")
                }

                Button(AppText.finishExpression, action: onFinishExpression)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isCommandInFlight)
                    .accessibilityIdentifier("reflection.finish")

                Button(AppText.keepSilence, action: onKeepSilence)
                    .buttonStyle(.borderless)
                    .disabled(isCommandInFlight)
                    .accessibilityIdentifier("reflection.keep-silence")
            }
        }
        .accessibilityIdentifier("reflection.expression")
    }

    private func distanceView(_ distance: IndoorDistanceState) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Text(AppText.addIndoorDistance)
                .font(.largeTitle.bold())
            Text(AppText.indoorDistanceMessage)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                TextField(
                    AppText.distancePlaceholder,
                    text: Binding(
                        get: { distance.kilometers },
                        set: { value in onChangeDistance(value) }
                    )
                )
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("reflection.distance")
                Text(AppText.kilometers)
                    .foregroundStyle(.secondary)
            }

            if distance.showsValidationError {
                Text(AppText.validDistanceRequired)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(AppText.saveDistance, action: onSaveDistance)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isCommandInFlight)
                .accessibilityIdentifier("reflection.save-distance")
            Button(AppText.skipDistance, action: onSkipDistance)
                .buttonStyle(.borderless)
                .disabled(isCommandInFlight)
                .accessibilityIdentifier("reflection.skip-distance")
            Spacer()
        }
    }

    private func enteringArtworkView(
        record: SharedActivityRecordV1,
        artwork: CurrentArtworkViewState
    ) -> some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color(record.expression.recordColor))
                    .frame(width: 96, height: 96)
                Image(systemName: "arrow.down")
                    .font(.title.bold())
                    .foregroundStyle(.white)
            }
            Text(AppText.recordJoinedArtwork)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(
                artwork.presentation.phase == .completed
                    ? AppText.artworkCompletedByRun
                    : AppText.artworkNowHasMarks(artwork.presentation.marks.count)
            )
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            if record.environment == .outdoor {
                RoutePreview(record: record)
            }
            Button(AppText.viewArtwork, action: onShowArtwork)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("reflection.view-artwork")
            Spacer()
        }
    }
}

private struct RoutePreview: View {
    let record: SharedActivityRecordV1

    private var coordinates: [CLLocationCoordinate2D] {
        record.routeSamples.compactMap { sample in
            guard sample.quality == .accepted else { return nil }
            return CLLocationCoordinate2D(latitude: sample.latitude, longitude: sample.longitude)
        }
    }

    private var segments: [[CLLocationCoordinate2D]] {
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
                sample.measuredAt.timeIntervalSince($0)
                    > LocationRouteAccumulator.maximumSegmentGap
            } ?? false
            let crossesPause = previousDate.map { previous in
                record.events.contains {
                    $0.occurredAt > previous && $0.occurredAt <= sample.measuredAt
                }
            } ?? false
            if crossesGap || crossesPause {
                if current.count >= 2 { result.append(current) }
                current = []
            }
            current.append(CLLocationCoordinate2D(
                latitude: sample.latitude,
                longitude: sample.longitude
            ))
            previousDate = sample.measuredAt
        }
        if current.count >= 2 { result.append(current) }
        return result
    }

    var body: some View {
        if !segments.isEmpty {
            Map(initialPosition: .region(region)) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    MapPolyline(coordinates: segment)
                        .stroke(.blue, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .allowsHitTesting(false)
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .accessibilityIdentifier("reflection.route")
        }
    }

    private var region: MKCoordinateRegion {
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (latitudes.min()! + latitudes.max()!) / 2,
            longitude: (longitudes.min()! + longitudes.max()!) / 2
        )
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: max(0.002, (latitudes.max()! - latitudes.min()!) * 1.4),
                longitudeDelta: max(0.002, (longitudes.max()! - longitudes.min()!) * 1.4)
            )
        )
    }
}

private extension Color {
    init(_ value: RecordColorValue) {
        self.init(
            .sRGB,
            red: value.red,
            green: value.green,
            blue: value.blue,
            opacity: value.opacity
        )
    }
}
