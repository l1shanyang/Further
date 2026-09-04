import SwiftUI

struct ReflectionFlowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            .navigationBarBackButtonHidden()
            .furtherPage()
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
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 11) {
                    Text(AppText.howDidItFeel)
                        .font(.title2.weight(.medium))
                    Text(AppText.chooseFeelingColor)
                        .foregroundStyle(FurtherPalette.secondaryText)
                }
                .padding(.top, 18)

                VStack(alignment: .leading, spacing: 15) {
                    Text(AppText.feelingColorSection)
                        .font(.body.weight(.semibold))

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                        spacing: 12
                    ) {
                        ForEach(Array(FeelingColorOption.all.enumerated()), id: \.element.id) { item in
                            let (index, option) = item
                            Button {
                                onSelectColor(option.color)
                            } label: {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(option.color.value))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(
                                                expression.feelingColor == option.color
                                                    ? FurtherPalette.primaryText
                                                    : FurtherPalette.quietBorder,
                                                lineWidth: expression.feelingColor == option.color ? 3 : 1
                                            )
                                    }
                                    .overlay {
                                        if expression.feelingColor == option.color {
                                            Image(systemName: "checkmark")
                                                .font(.headline.weight(.semibold))
                                                .foregroundStyle(FurtherPalette.primaryText)
                                                .padding(8)
                                                .background(FurtherPalette.raised, in: Circle())
                                        }
                                    }
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
                }
                .padding(.top, 30)

                VStack(alignment: .leading, spacing: 8) {
                    Text(AppText.shortNote)
                        .font(.body.weight(.semibold))
                    Text(AppText.shortNoteMessage)
                        .font(.footnote)
                        .foregroundStyle(FurtherPalette.secondaryText)
                    TextField(
                        AppText.shortNotePlaceholder,
                        text: Binding(
                            get: { expression.note },
                            set: { value in onChangeNote(value) }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(3...4)
                    .padding(13)
                    .background(FurtherPalette.background)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(FurtherPalette.quietBorder)
                    }
                    .disabled(isCommandInFlight)
                    .accessibilityIdentifier("reflection.note")

                    if !expression.note.isEmpty {
                        Text(AppText.draftSaved)
                            .font(.footnote)
                            .foregroundStyle(FurtherPalette.secondaryText)
                    }
                }
                .padding(.top, 30)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .accessibilityIdentifier("reflection.expression")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FurtherBottomActions {
                Button(AppText.finishExpression, action: onFinishExpression)
                    .buttonStyle(FurtherPrimaryButtonStyle())
                    .disabled(isCommandInFlight || expression.feelingColor == nil)
                    .accessibilityIdentifier("reflection.finish")

                Button(AppText.keepSilence, action: onKeepSilence)
                    .buttonStyle(FurtherSecondaryButtonStyle())
                    .disabled(isCommandInFlight)
                    .accessibilityIdentifier("reflection.keep-silence")
            }
        }
    }

    private func distanceView(_ distance: IndoorDistanceState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 11) {
                    Text(AppText.addIndoorDistance)
                        .font(.title2.weight(.medium))
                    Text(AppText.indoorDistanceMessage)
                        .foregroundStyle(FurtherPalette.secondaryText)
                }
                .padding(.top, 18)

                VStack(alignment: .leading, spacing: 8) {
                    Text(AppText.manualDistance)
                        .font(.footnote)
                        .foregroundStyle(FurtherPalette.secondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        TextField(
                            "—",
                            text: Binding(
                                get: { distance.distanceInput },
                                set: { value in onChangeDistance(value) }
                            )
                        )
                        .keyboardType(.decimalPad)
                        .font(.system(.largeTitle, design: .monospaced))
                        .accessibilityIdentifier("reflection.distance")
                        Text(distanceUnit.symbol)
                            .foregroundStyle(FurtherPalette.secondaryText)
                    }
                    .padding(.bottom, 9)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(FurtherPalette.primaryText).frame(height: 1)
                    }

                    Text(distanceMessage(distance))
                        .font(.footnote)
                        .foregroundStyle(FurtherPalette.secondaryText)
                }
                .padding(.top, 44)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .accessibilityIdentifier("reflection.distance-entry")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FurtherBottomActions {
                Button(AppText.saveDistance, action: onSaveDistance)
                    .buttonStyle(FurtherPrimaryButtonStyle())
                    .disabled(isCommandInFlight || !hasValidDistance(distance.distanceInput))
                    .accessibilityIdentifier("reflection.save-distance")
                Button(AppText.skipDistance, action: onSkipDistance)
                    .buttonStyle(FurtherSecondaryButtonStyle())
                    .disabled(isCommandInFlight)
                    .accessibilityIdentifier("reflection.skip-distance")
            }
        }
    }

    private func enteringArtworkView(
        record: SharedActivityRecordV1,
        artwork: CurrentArtworkViewState
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BasicArtworkView(description: artwork.presentation)
                    .aspectRatio(335.0 / 460.0, contentMode: .fit)
                    .padding(.top, 30)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))

                Text(AppText.recordJoinedArtwork)
                    .font(.title2.weight(.medium))
                    .padding(.top, 26)
                    .accessibilityAddTraits(.isHeader)

                Text(
                    artwork.presentation.phase == .completed
                        ? AppText.artworkCompletedByRun
                        : AppText.expressionLocked
                )
                .foregroundStyle(FurtherPalette.secondaryText)
                .padding(.top, 11)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .accessibilityIdentifier("reflection.artwork-entry")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FurtherBottomActions {
                Button(AppText.viewArtwork, action: onShowArtwork)
                    .buttonStyle(FurtherPrimaryButtonStyle())
                    .accessibilityIdentifier("reflection.view-artwork")
            }
        }
    }

    private func hasValidDistance(_ input: String) -> Bool {
        ManualDistanceParser.meters(from: input, unit: distanceUnit) != nil
    }

    private func distanceMessage(_ state: IndoorDistanceState) -> String {
        if state.distanceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return AppText.distanceRemainsUnknown
        }
        return hasValidDistance(state.distanceInput)
            ? AppText.manualDistanceWillBeSaved
            : AppText.validDistanceRequired
    }
}

extension Color {
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
