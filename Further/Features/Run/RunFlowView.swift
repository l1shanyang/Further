import SwiftUI

struct RunFlowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var countdownFontSize = 112
    @ScaledMetric(relativeTo: .largeTitle) private var trackingFontSize = 58
    @ScaledMetric(relativeTo: .title) private var confirmationFontSize = 44

    let state: RunFlowViewState
    let distanceUnit: DistanceUnit
    let isCommandInFlight: Bool
    let onChooseIndoor: () -> Void
    let onChooseOutdoor: () -> Void
    let onCancelPreparation: () -> Void
    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onRequestEnd: () -> Void
    let onCancelEnd: () -> Void
    let onConfirmEnd: () -> Void

    var body: some View {
        content
            .padding(24)
            .navigationBarBackButtonHidden()
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .environmentSelection:
            environmentSelection
        case let .readyIndoor(isStarting):
            ready(environment: .indoor, authorization: nil, isStarting: isStarting)
        case let .readyOutdoor(authorization, isStarting):
            ready(environment: .outdoor, authorization: authorization, isStarting: isStarting)
        case let .countdown(remainingSeconds):
            countdown(remainingSeconds: remainingSeconds)
        case let .tracking(activeState):
            tracking(activeState)
        case let .endingConfirmation(previous):
            endingConfirmation(previous)
        case .awaitingReflection:
            awaitingReflection
        }
    }

    private var environmentSelection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(AppText.chooseRunEnvironment)
                    .font(.largeTitle.bold())
                Text(AppText.indoorRunMessage)
                    .foregroundStyle(.secondary)

                Button(AppText.indoorRun, action: onChooseIndoor)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("run.choose-indoor")
                Button(AppText.outdoorRun, action: onChooseOutdoor)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("run.choose-outdoor")
                Button(AppText.cancel, action: onCancelPreparation)
                    .buttonStyle(.borderless)
            }
            .frame(maxWidth: .infinity, minHeight: 520, alignment: .center)
        }
        .accessibilityIdentifier("run.environment-selection")
    }

    private func ready(
        environment: RunningEnvironment,
        authorization: LocationAuthorizationState?,
        isStarting: Bool
    ) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "figure.run")
                    .font(.system(size: 52))
                Text(AppText.readyToRun)
                    .font(.largeTitle.bold())
                Text(AppText.startRunPromise)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                if environment == .outdoor, authorization?.canRecordLocation != true {
                    Text(AppText.outdoorLocationUnavailable)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("run.location-unavailable")
                }

                Button {
                    onStart()
                } label: {
                    if isStarting {
                        ProgressView()
                    } else {
                        Text(AppText.startRun)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isStarting)
                .accessibilityIdentifier("run.start")

                Button(AppText.cancel, action: onCancelPreparation)
                    .buttonStyle(.borderless)
                    .disabled(isStarting)
            }
            .frame(maxWidth: .infinity, minHeight: 520, alignment: .center)
        }
        .accessibilityIdentifier("run.ready")
    }

    private func countdown(remainingSeconds: Int) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(String(remainingSeconds))
                .font(.system(size: countdownFontSize, weight: .bold, design: .rounded))
                .contentTransition(reduceMotion ? .identity : .numericText())
                .minimumScaleFactor(0.5)
                .accessibilityIdentifier("run.countdown")
            Text(AppText.runHasStarted)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func tracking(_ activeState: ActiveRunViewState) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                Label(
                    activeState.isPaused ? AppText.runPaused : AppText.runInProgress,
                    systemImage: activeState.isPaused ? "pause.fill" : "figure.run"
                )
                .font(.headline)
                .foregroundStyle(activeState.isPaused ? Color.orange : Color.secondary)
                Text(formatDuration(activeState.activeDuration))
                    .font(.system(size: trackingFontSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.45)
                    .accessibilityIdentifier("run.active-time")
                VStack(spacing: 4) {
                    Text(AppText.distance)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDistance(activeState.distance))
                        .font(.title3)
                        .accessibilityIdentifier("run.distance-value")
                }

                ViewThatFits(in: .horizontal) {
                    runActions(activeState, axis: .horizontal)
                    runActions(activeState, axis: .vertical)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 520, alignment: .center)
        }
        .accessibilityIdentifier("run.tracking")
    }

    private func runActions(_ activeState: ActiveRunViewState, axis: Axis) -> some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 16))
            : AnyLayout(VStackLayout(spacing: 12))
        return layout {
            Button(
                activeState.isPaused ? AppText.resumeRun : AppText.pauseRun,
                action: activeState.isPaused ? onResume : onPause
            )
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isCommandInFlight)
            .accessibilityIdentifier(activeState.isPaused ? "run.resume" : "run.pause")

            Button(AppText.endRun, role: .destructive, action: onRequestEnd)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isCommandInFlight)
                .accessibilityIdentifier("run.end")
        }
    }

    private var awaitingReflection: some View {
        ContentUnavailableView {
            Label(AppText.runSaved, systemImage: "checkmark.circle")
        } description: {
            Text(AppText.runSavedMessage)
        }
        .accessibilityIdentifier("run.awaiting-reflection")
    }

    private func endingConfirmation(_ previous: ActiveRunViewState) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                Text(AppText.endRunTitle)
                    .font(.largeTitle.bold())
                Text(formatDuration(previous.activeDuration))
                    .font(.system(
                        size: confirmationFontSize,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                Text(AppText.endRunMessage)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button(AppText.endRun, role: .destructive, action: onConfirmEnd)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isCommandInFlight)
                    .accessibilityIdentifier("run.confirm-end")
                Button(AppText.keepRunning, action: onCancelEnd)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isCommandInFlight)
                    .accessibilityIdentifier("run.keep-running")
            }
            .frame(maxWidth: .infinity, minHeight: 520, alignment: .center)
        }
        .accessibilityIdentifier("run.ending-confirmation")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func formatDistance(_ distance: ActivityDistance?) -> String {
        distanceUnit.format(meters: distance?.meters)
    }
}

private extension ActiveRunViewState {
    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}
