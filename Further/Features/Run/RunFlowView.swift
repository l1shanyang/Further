import SwiftUI

struct RunFlowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var countdownFontSize = 112
    @ScaledMetric(relativeTo: .largeTitle) private var trackingFontSize = 52

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
            .navigationBarBackButtonHidden()
            .furtherPage()
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .environmentSelection:
            environmentSelection(selected: nil, authorization: nil, isStarting: false)
        case let .readyIndoor(isStarting):
            environmentSelection(selected: .indoor, authorization: nil, isStarting: isStarting)
        case let .readyOutdoor(authorization, isStarting):
            environmentSelection(
                selected: .outdoor,
                authorization: authorization,
                isStarting: isStarting
            )
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

    private func environmentSelection(
        selected: RunningEnvironment?,
        authorization: LocationAuthorizationState?,
        isStarting: Bool
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FurtherTopBar(title: AppText.prepareRun, onBack: onCancelPreparation)

                VStack(alignment: .leading, spacing: 11) {
                    Text(AppText.chooseRunEnvironment)
                        .font(.title2.weight(.medium))
                    Text(AppText.startRunPromise)
                        .foregroundStyle(FurtherPalette.secondaryText)
                }
                .padding(.top, 18)

                VStack(spacing: 0) {
                    Divider().overlay(FurtherPalette.quietBorder)
                    environmentRow(
                        title: AppText.outdoorRun,
                        message: authorization?.canRecordLocation == false
                            ? AppText.outdoorLocationUnavailable
                            : AppText.outdoorRunMessage,
                        isSelected: selected == .outdoor,
                        action: onChooseOutdoor,
                        identifier: "run.choose-outdoor"
                    )
                    Divider().overlay(FurtherPalette.quietBorder)
                    environmentRow(
                        title: AppText.indoorRun,
                        message: AppText.indoorRunMessage,
                        isSelected: selected == .indoor,
                        action: onChooseIndoor,
                        identifier: "run.choose-indoor"
                    )
                    Divider().overlay(FurtherPalette.quietBorder)
                }
                .padding(.top, 30)

                Text(AppText.locationRequestedOnStart)
                    .font(.footnote)
                    .foregroundStyle(FurtherPalette.secondaryText)
                    .padding(.top, 18)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .accessibilityIdentifier(selected == nil ? "run.environment-selection" : "run.ready")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selected != nil {
                FurtherBottomActions {
                    Button {
                        onStart()
                    } label: {
                        if isStarting { ProgressView() } else { Text(AppText.startRun) }
                    }
                    .buttonStyle(FurtherPrimaryButtonStyle())
                    .disabled(isStarting)
                    .accessibilityIdentifier("run.start")
                }
            }
        }
    }

    private func environmentRow(
        title: String,
        message: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        identifier: String
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(FurtherPalette.primaryText)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(FurtherPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(
                            message == AppText.outdoorLocationUnavailable
                                ? "run.location-unavailable"
                                : ""
                        )
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                }
            }
            .frame(minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private func countdown(remainingSeconds: Int) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Text(String(remainingSeconds))
                .font(.system(size: countdownFontSize, weight: .medium, design: .monospaced))
                .contentTransition(reduceMotion ? .identity : .numericText())
                .minimumScaleFactor(0.5)
                .accessibilityIdentifier("run.countdown")
            Text(AppText.runHasStarted)
                .foregroundStyle(FurtherPalette.secondaryText)
            Spacer()
        }
        .padding(20)
    }

    private func tracking(_ activeState: ActiveRunViewState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FurtherTopBar(title: activeState.isPaused ? AppText.runPaused : AppText.runInProgress)

                VStack(alignment: .leading, spacing: 0) {
                    metric(
                        label: AppText.activeTime,
                        value: formatDuration(activeState.activeDuration),
                        isUnknown: false,
                        identifier: "run.active-time"
                    )
                    metric(
                        label: AppText.distance,
                        value: formatDistance(activeState.distance),
                        isUnknown: activeState.distance == nil,
                        identifier: "run.distance-value"
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 520, alignment: .center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .accessibilityIdentifier("run.tracking")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FurtherBottomActions {
                Button(
                    activeState.isPaused ? AppText.resumeRun : AppText.pauseRun,
                    action: activeState.isPaused ? onResume : onPause
                )
                .buttonStyle(FurtherPrimaryButtonStyle())
                .disabled(isCommandInFlight)
                .accessibilityIdentifier(activeState.isPaused ? "run.resume" : "run.pause")

                Button(AppText.endRun, role: .destructive, action: onRequestEnd)
                    .buttonStyle(FurtherSecondaryButtonStyle())
                    .disabled(isCommandInFlight)
                    .accessibilityIdentifier("run.end")
            }
        }
    }

    private func metric(
        label: String,
        value: String,
        isUnknown: Bool,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(FurtherPalette.secondaryText)
            Text(value)
                .font(
                    isUnknown
                        ? .system(.title, design: .default, weight: .regular)
                        : .system(size: trackingFontSize, weight: .semibold, design: .monospaced)
                )
                .monospacedDigit()
                .minimumScaleFactor(0.45)
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
        .overlay(alignment: .bottom) {
            Rectangle().fill(FurtherPalette.quietBorder).frame(height: 1)
        }
    }

    private var awaitingReflection: some View {
        ContentUnavailableView {
            Text(AppText.runSaved)
        } description: {
            Text(AppText.runSavedMessage)
        }
        .accessibilityIdentifier("run.awaiting-reflection")
    }

    private func endingConfirmation(_ previous: ActiveRunViewState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 150)
                Rectangle()
                    .fill(FurtherPalette.primaryText)
                    .frame(width: 44, height: 2)
                    .padding(.bottom, 24)
                Text(AppText.endRunTitle)
                    .font(.title2.weight(.medium))
                Text(AppText.endRunMessage)
                    .foregroundStyle(FurtherPalette.secondaryText)
                    .padding(.top, 11)
                Text(formatDuration(previous.activeDuration))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(FurtherPalette.secondaryText)
                    .padding(.top, 24)
                Spacer(minLength: 150)
            }
            .frame(maxWidth: .infinity, minHeight: 560, alignment: .leading)
            .padding(.horizontal, 20)
        }
        .accessibilityIdentifier("run.ending-confirmation")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FurtherBottomActions {
                Button(AppText.endRun, role: .destructive, action: onConfirmEnd)
                    .buttonStyle(FurtherPrimaryButtonStyle())
                    .disabled(isCommandInFlight)
                    .accessibilityIdentifier("run.confirm-end")
                Button(AppText.keepRunning, action: onCancelEnd)
                    .buttonStyle(FurtherSecondaryButtonStyle())
                    .disabled(isCommandInFlight)
                    .accessibilityIdentifier("run.keep-running")
            }
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
        distanceUnit.format(meters: distance?.meters)
    }
}

private extension ActiveRunViewState {
    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

}
