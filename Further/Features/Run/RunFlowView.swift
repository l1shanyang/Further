import SwiftUI

struct RunFlowView: View {
    let state: RunFlowViewState
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
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
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
            Spacer()
        }
    }

    private func ready(
        environment: RunningEnvironment,
        authorization: LocationAuthorizationState?,
        isStarting: Bool
    ) -> some View {
        VStack(spacing: 24) {
            Spacer()
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
            Spacer()
        }
    }

    private func countdown(remainingSeconds: Int) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(String(remainingSeconds))
                .font(.system(size: 112, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .accessibilityIdentifier("run.countdown")
            Text(AppText.runHasStarted)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func tracking(_ activeState: ActiveRunViewState) -> some View {
        VStack(spacing: 28) {
            Spacer()
            Text(activeState.isPaused ? AppText.runPaused : AppText.runInProgress)
                .font(.headline)
                .foregroundStyle(activeState.isPaused ? Color.orange : Color.secondary)
            Text(formatDuration(activeState.activeDuration))
                .font(.system(size: 58, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .accessibilityIdentifier("run.active-time")
            VStack(spacing: 4) {
                Text(AppText.distance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatDistance(activeState.distance))
                    .font(.title3)
                    .accessibilityIdentifier("run.distance-value")
            }

            HStack(spacing: 16) {
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
            Spacer()
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
        VStack(spacing: 22) {
            Spacer()
            Text(AppText.endRunTitle)
                .font(.largeTitle.bold())
            Text(formatDuration(previous.activeDuration))
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
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
            Spacer()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func formatDistance(_ distance: ActivityDistance?) -> String {
        guard let distance else { return AppText.notRecorded }
        return String(format: "%.2f %@", distance.meters / 1_000, AppText.kilometers)
    }
}

private extension ActiveRunViewState {
    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}
