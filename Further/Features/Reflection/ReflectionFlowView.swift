import SwiftUI

struct ReflectionFlowView: View {
    let state: ReflectionFlowViewState
    let distanceUnit: DistanceUnit
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
                                        Image(systemName: "checkmark")
                                            .font(.headline.bold())
                                            .foregroundStyle(.primary)
                                            .padding(8)
                                            .background(.regularMaterial, in: Circle())
                                    }
                                }
                                .frame(width: 68, height: 68)
                        }
                        .buttonStyle(.plain)
                        .disabled(isCommandInFlight)
                        .accessibilityLabel(AppText.feelingColor(index + 1))
                        .accessibilityAddTraits(
                            expression.feelingColor == option.color ? .isSelected : []
                        )
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
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(AppText.addIndoorDistance)
                    .font(.largeTitle.bold())
                Text(AppText.indoorDistanceMessage)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline) {
                    TextField(
                        AppText.distancePlaceholder,
                        text: Binding(
                            get: { distance.distanceInput },
                            set: { value in onChangeDistance(value) }
                        )
                    )
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("reflection.distance")
                    Text(distanceUnit.symbol)
                        .foregroundStyle(.secondary)
                }

                if distance.showsValidationError {
                    Label(AppText.validDistanceRequired, systemImage: "exclamationmark.circle")
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
            }
            .frame(maxWidth: .infinity, minHeight: 520, alignment: .center)
        }
        .accessibilityIdentifier("reflection.distance-entry")
    }

    private func enteringArtworkView(
        record: SharedActivityRecordV1,
        artwork: CurrentArtworkViewState
    ) -> some View {
        ScrollView {
            VStack(spacing: 26) {
                ZStack {
                    Circle()
                        .fill(Color(record.expression.recordColor))
                        .frame(width: 96, height: 96)
                    Image(systemName: "arrow.down")
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                        .padding(10)
                        .background(.regularMaterial, in: Circle())
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
                    ActivityRouteView(record: record)
                }
                Button(AppText.viewArtwork, action: onShowArtwork)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("reflection.view-artwork")
            }
            .frame(maxWidth: .infinity, minHeight: 520, alignment: .center)
        }
        .accessibilityIdentifier("reflection.artwork-entry")
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
