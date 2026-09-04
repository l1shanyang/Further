import SwiftUI
import UIKit

enum FurtherPalette {
    static let background = adaptive(light: 0xF2F1ED, dark: 0x141414)
    static let surface = adaptive(light: 0xEAE9E5, dark: 0x1B1B1A)
    static let raised = adaptive(light: 0xFAF9F6, dark: 0x222220)
    static let primaryText = adaptive(light: 0x20201F, dark: 0xE8E6E1)
    static let secondaryText = adaptive(
        light: 0x66645F,
        dark: 0xA5A29B,
        highContrastLight: 0x464540,
        highContrastDark: 0xC3C0B9
    )
    static let quietBorder = adaptive(
        light: 0xD4D2CC,
        dark: 0x343330,
        highContrastLight: 0x7C7871,
        highContrastDark: 0x7C7871
    )
    static let clearBorder = adaptive(light: 0x7C7871, dark: 0x7C7871)
    static let action = adaptive(light: 0xE5E3DD, dark: 0x272725)
    static let actionPressed = adaptive(light: 0xDCD9D2, dark: 0x302F2C)

    private static func adaptive(
        light: UInt32,
        dark: UInt32,
        highContrastLight: UInt32? = nil,
        highContrastDark: UInt32? = nil
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let value = if traits.accessibilityContrast == .high {
                isDark ? highContrastDark ?? dark : highContrastLight ?? light
            } else {
                isDark ? dark : light
            }
            return UIColor(hex: value)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct FurtherPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? FurtherPalette.primaryText : FurtherPalette.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 14)
            .background(
                configuration.isPressed ? FurtherPalette.actionPressed : FurtherPalette.action,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isEnabled ? FurtherPalette.clearBorder : FurtherPalette.quietBorder)
            }
            .opacity(isEnabled ? 1 : 0.62)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct FurtherSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(FurtherPalette.primaryText)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
            .background(
                configuration.isPressed ? FurtherPalette.action.opacity(0.7) : .clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .opacity(isEnabled ? 1 : 0.5)
    }
}

struct FurtherBottomActions<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 7) { content }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(FurtherPalette.background)
            .overlay(alignment: .top) {
                Rectangle().fill(FurtherPalette.quietBorder).frame(height: 1)
            }
    }
}

struct FurtherTopBar<Trailing: View>: View {
    let title: String
    let onBack: (() -> Void)?
    @ViewBuilder let trailing: Trailing

    init(
        title: String,
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.onBack = onBack
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let onBack {
                    Button(action: onBack) {
                        Label(AppText.back, systemImage: "chevron.left")
                            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    }
                    .accessibilityLabel(AppText.back)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(title)
                .font(.headline)
                .foregroundStyle(FurtherPalette.primaryText)
                .lineLimit(1)

            trailing
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.plain)
        .foregroundStyle(FurtherPalette.secondaryText)
        .frame(minHeight: 54)
    }
}

extension View {
    func furtherPage() -> some View {
        foregroundStyle(FurtherPalette.primaryText)
            .background(FurtherPalette.background.ignoresSafeArea())
            .tint(FurtherPalette.primaryText)
            .toolbar(.hidden, for: .navigationBar)
    }
}

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: AppRootModel

    init(model: AppRootModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack { content }
            .furtherPage()
            .task { await model.start() }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active: Task { await model.appBecameActive() }
                case .background: Task { await model.appDidEnterBackground() }
                case .inactive: break
                @unknown default: break
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
            ProgressView().accessibilityIdentifier("root.loading")
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
        return notice.interruptedActivityCount > 0
            ? AppText.interruptedRunSaved
            : AppText.reflectionSaved
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
            VStack(alignment: .leading, spacing: 0) {
                FurtherTopBar(
                    title: AppText.chooseCycleNavigationTitle,
                    onBack: state.context.isNextArtwork ? onCancel : nil
                )

                VStack(alignment: .leading, spacing: 11) {
                    Text(state.context.isNextArtwork ? AppText.chooseNextCycleTitle : AppText.chooseFirstCycleTitle)
                        .font(.title2.weight(.medium))
                    Text(AppText.chooseCycleMessage)
                        .font(.body)
                        .foregroundStyle(FurtherPalette.secondaryText)
                }
                .padding(.top, 18)

                optionSection(
                    title: AppText.timeCycle,
                    options: ArtworkCycleOption.allCases.filter(\.isTimeCycle)
                )
                optionSection(
                    title: AppText.milestoneCycle,
                    options: ArtworkCycleOption.allCases.filter { !$0.isTimeCycle }
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .accessibilityIdentifier("cycle.selection")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FurtherBottomActions {
                Button {
                    onConfirm(selection.cycle)
                } label: {
                    if state.isCreating { ProgressView() } else { Text(AppText.beginArtwork) }
                }
                .buttonStyle(FurtherPrimaryButtonStyle())
                .disabled(state.isCreating)
                .accessibilityIdentifier("cycle.confirm")
            }
        }
        .navigationBarBackButtonHidden()
        .furtherPage()
    }

    private func optionSection(
        title: String,
        options: [ArtworkCycleOption]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FurtherPalette.secondaryText)
                .padding(.bottom, 8)

            Divider().overlay(FurtherPalette.quietBorder)
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    HStack(spacing: 16) {
                        Text(option.title(distanceUnit: distanceUnit))
                        Spacer()
                        if selection == option {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .frame(minHeight: 58)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
                .accessibilityIdentifier("cycle.option.\(option.rawValue)")
                Divider().overlay(FurtherPalette.quietBorder)
            }
        }
        .padding(.top, 30)
    }
}

private extension ArtworkCycleSelectionContext {
    var isNextArtwork: Bool {
        if case .nextArtwork = self { return true }
        return false
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
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button(action: onLookback) {
                        Text(AppText.lookback)
                            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                        .accessibilityIdentifier("artwork.lookback")
                    Spacer()
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(AppText.settings)
                    .accessibilityIdentifier("artwork.settings")
                }
                .buttonStyle(.plain)
                .foregroundStyle(FurtherPalette.secondaryText)
                .frame(minHeight: 53)

                Text(title)
                    .font(.title2.weight(.medium))
                    .padding(.top, 15)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(cycleDescription)
                        .font(.footnote)
                        .foregroundStyle(FurtherPalette.secondaryText)
                    Spacer()
                    Button(action: onCollection) {
                        Text(AppText.collection)
                            .font(.footnote)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                            .underline(color: FurtherPalette.quietBorder)
                            .foregroundStyle(FurtherPalette.secondaryText)
                    }
                        .accessibilityIdentifier("artwork.collection")
                }
                .frame(minHeight: 32)

                BasicArtworkView(description: state.presentation)
                    .aspectRatio(335.0 / 460.0, contentMode: .fit)
                    .padding(.top, 14)

                Text(state.presentation.phase == .blank ? AppText.blankArtworkMessage : " ")
                    .font(.body)
                    .foregroundStyle(FurtherPalette.secondaryText)
                    .padding(.top, 14)
                    .accessibilityHidden(state.presentation.phase != .blank)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .accessibilityIdentifier("artwork.current")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FurtherBottomActions {
                Button(
                    state.presentation.phase == .completed
                        ? AppText.startNextArtwork
                        : AppText.prepareRun,
                    action: state.presentation.phase == .completed
                        ? onStartNextArtwork
                        : onStartRun
                )
                .buttonStyle(FurtherPrimaryButtonStyle())
                .accessibilityLabel(
                    state.presentation.phase == .completed
                        ? AppText.startNextArtwork
                        : AppText.prepareRunAccessibilityLabel
                )
                .accessibilityIdentifier(
                    state.presentation.phase == .completed
                        ? "artwork.start-next"
                        : "artwork.prepare-run"
                )
            }
        }
        .navigationBarBackButtonHidden()
        .furtherPage()
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
                Rectangle().fill(FurtherPalette.surface)
                Rectangle().stroke(FurtherPalette.quietBorder, lineWidth: 1)

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
