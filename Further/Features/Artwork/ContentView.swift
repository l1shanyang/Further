import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: AppRootModel

    init(model: AppRootModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            content
        }
        .task {
            await model.start()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task { await model.appBecameActive() }
            case .background:
                Task { await model.appDidEnterBackground() }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .alert(
            AppText.recoveryNoticeTitle,
            isPresented: Binding(
                get: { model.recoveryNotice != nil },
                set: { if !$0 { model.dismissRecoveryNotice() } }
            )
        ) {
            Button(AppText.ok) { model.dismissRecoveryNotice() }
        } message: {
            Text(recoveryNoticeMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .accessibilityIdentifier("root.loading")
        case let .cycleSelection(selection):
            ArtworkCycleSelectionView(
                state: selection,
                distanceUnit: model.distanceUnit,
                onConfirm: { cycle in Task { await model.createArtwork(cycle: cycle) } },
                onCancel: model.cancelNextArtworkSelection
            )
        case let .currentArtwork(state):
            CurrentArtworkView(
                state: state,
                distanceUnit: model.distanceUnit,
                onStartRun: model.beginRunPreparation,
                onStartNextArtwork: model.beginNextArtwork,
                onLookback: { Task { await model.showLookback() } },
                onCollection: { Task { await model.showCollection() } },
                onSettings: { Task { await model.showSettings() } }
            )
        case let .run(state):
            RunFlowView(
                state: state,
                distanceUnit: model.distanceUnit,
                isCommandInFlight: model.isRunCommandInFlight,
                onChooseIndoor: model.chooseIndoorRun,
                onChooseOutdoor: { Task { await model.chooseOutdoorRun() } },
                onCancelPreparation: model.cancelRunPreparation,
                onStart: { Task { await model.confirmSelectedRunStart() } },
                onPause: { Task { await model.pauseRun() } },
                onResume: { Task { await model.resumeRun() } },
                onRequestEnd: model.requestRunEnd,
                onCancelEnd: model.cancelRunEnd,
                onConfirmEnd: { Task { await model.confirmRunEnd() } }
            )
        case let .reflection(state):
            ReflectionFlowView(
                state: state,
                distanceUnit: model.distanceUnit,
                isCommandInFlight: model.isReflectionCommandInFlight,
                onSelectColor: model.selectFeelingColor,
                onChangeNote: model.updateReflectionNote,
                onFinishExpression: { Task { await model.finishReflectionExpression() } },
                onKeepSilence: { Task { await model.keepReflectionSilent() } },
                onChangeDistance: model.updateIndoorDistance,
                onSaveDistance: { Task { await model.saveIndoorDistance() } },
                onSkipDistance: { Task { await model.skipIndoorDistance() } },
                onShowArtwork: model.showUpdatedArtwork
            )
        case let .lookback(state):
            LookbackView(
                state: state,
                distanceUnit: model.distanceUnit,
                onSelectRecord: { id in Task { await model.selectLookbackRecord(id) } },
                onBack: model.backFromLookback
            )
        case let .collection(state):
            CollectionView(
                state: state,
                distanceUnit: model.distanceUnit,
                onSelectArtwork: model.selectCollectedArtwork,
                onBack: model.backFromCollection
            )
        case let .settings(state):
            SettingsView(
                state: state,
                onSelectDistanceUnit: model.selectDistanceUnit,
                onRequestHealthAuthorization: {
                    Task { await model.requestHealthAuthorization() }
                },
                onBack: model.backFromSettings
            )
        case .blocked:
            ContentUnavailableView {
                Label(AppText.dataUnavailableTitle, systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text(AppText.dataUnavailableMessage)
            } actions: {
                Button(AppText.tryAgain) { Task { await model.start() } }
            }
            .accessibilityIdentifier("root.blocked")
        }
    }

    private var recoveryNoticeMessage: String {
        guard let notice = model.recoveryNotice else { return "" }
        if notice.interruptedActivityCount > 0 {
            return AppText.interruptedRunSaved
        }
        return AppText.reflectionSaved
    }
}

private struct ArtworkCycleSelectionView: View {
    let state: ArtworkCycleSelectionState
    let distanceUnit: DistanceUnit
    let onConfirm: (ArtworkCycle) -> Void
    let onCancel: () -> Void

    @State private var selection = ArtworkCycleOption.oneMonth

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppText.productName)
                        .font(.headline)
                    Text(AppText.chooseCycleTitle)
                        .font(.largeTitle.bold())
                    Text(AppText.chooseCycleMessage)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                optionSection(
                    title: AppText.timeCycle,
                    options: ArtworkCycleOption.allCases.filter(\.isTimeCycle)
                )
                optionSection(
                    title: AppText.milestoneCycle,
                    options: ArtworkCycleOption.allCases.filter { !$0.isTimeCycle }
                )

                Button {
                    onConfirm(selection.cycle)
                } label: {
                    HStack {
                        Spacer()
                        if state.isCreating {
                            ProgressView()
                        } else {
                            Text(AppText.beginArtwork)
                        }
                        Spacer()
                    }
                    .frame(minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isCreating)
                .accessibilityIdentifier("cycle.confirm")
            }
            .padding(24)
        }
        .toolbar {
            if case .nextArtwork = state.context {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppText.back, action: onCancel)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .accessibilityIdentifier("cycle.selection")
    }

    private func optionSection(
        title: String,
        options: [ArtworkCycleOption]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    HStack {
                        Text(option.title(distanceUnit: distanceUnit))
                        Spacer()
                        Image(systemName: selection == option ? "circle.inset.filled" : "circle")
                            .foregroundStyle(selection == option ? Color.primary : Color.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 9)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
                .accessibilityIdentifier("cycle.option.\(option.rawValue)")
            }
        }
    }
}

private struct CurrentArtworkView: View {
    let state: CurrentArtworkViewState
    let distanceUnit: DistanceUnit
    let onStartRun: () -> Void
    let onStartNextArtwork: () -> Void
    let onLookback: () -> Void
    let onCollection: () -> Void
    let onSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(AppText.productName)
                        .font(.headline)
                    Text(title)
                        .font(.largeTitle.bold())
                    Text(cycleDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                BasicArtworkView(description: state.presentation)
                    .aspectRatio(0.82, contentMode: .fit)

                if state.presentation.phase == .blank {
                    Text(AppText.blankArtworkMessage)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                if state.presentation.phase == .completed {
                    Button(AppText.startNextArtwork, action: onStartNextArtwork)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("artwork.start-next")
                } else {
                    Button(AppText.prepareRun, action: onStartRun)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("artwork.prepare-run")
                }

                Button(AppText.lookback, action: onLookback)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("artwork.lookback")

                Button(AppText.collection, action: onCollection)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("artwork.collection")

                Button(AppText.settings, action: onSettings)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("artwork.settings")
            }
            .padding(24)
        }
        .navigationBarBackButtonHidden()
        .accessibilityIdentifier("artwork.current")
    }

    private var title: String {
        switch state.presentation.phase {
        case .blank: AppText.blankArtworkTitle
        case .accumulating: AppText.accumulatingArtworkTitle
        case .completed: AppText.completedArtworkTitle
        }
    }

    private var cycleDescription: String {
        switch state.artwork.cycle {
        case let .time(duration):
            switch duration {
            case .oneMonth: AppText.oneMonth
            case .threeMonths: AppText.threeMonths
            case .oneYear: AppText.oneYear
            }
        case let .milestone(milestone):
            distanceUnit.format(meters: milestone.distanceMeters)
        }
    }
}

struct BasicArtworkView: View {
    let description: BasicArtworkDescription

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.secondary.opacity(0.06))
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.secondary.opacity(0.14), lineWidth: 1)

                ForEach(description.marks) { mark in
                    Circle()
                        .fill(Color(
                            red: mark.color.red,
                            green: mark.color.green,
                            blue: mark.color.blue,
                            opacity: mark.color.opacity
                        ))
                        .frame(
                            width: geometry.size.width * mark.normalizedDiameter,
                            height: geometry.size.width * mark.normalizedDiameter
                        )
                        .position(
                            x: geometry.size.width * mark.normalizedX,
                            y: geometry.size.height * mark.normalizedY
                        )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppText.artworkCanvas)
        .accessibilityValue(AppText.artworkMarkCount(description.marks.count))
        .accessibilityIdentifier("artwork.canvas")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        AppComposition.testing().rootView
    }
}
