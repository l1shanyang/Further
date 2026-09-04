import SwiftUI
import UIKit

struct SettingsView: View {
    let state: SettingsViewState
    let onSelectDistanceUnit: (DistanceUnit) -> Void
    let onRequestHealthAuthorization: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FurtherTopBar(title: AppText.settings, onBack: onBack)

                Text(AppText.settings)
                    .font(.title2.weight(.medium))
                    .padding(.top, 18)

                sectionTitle(AppText.distanceUnit)
                VStack(spacing: 0) {
                    quietRule
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(AppText.displayUnit)
                            Text(AppText.distanceUnitMessage)
                                .font(.footnote)
                                .foregroundStyle(FurtherPalette.secondaryText)
                        }
                        Spacer(minLength: 8)
                        HStack(spacing: 6) {
                            ForEach(DistanceUnit.allCases, id: \.self) { unit in
                                Button(unit.title) { onSelectDistanceUnit(unit) }
                                    .font(.footnote)
                                    .frame(minWidth: 52, minHeight: 44)
                                    .background(
                                        state.distanceUnit == unit
                                            ? FurtherPalette.primaryText
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    )
                                    .foregroundStyle(
                                        state.distanceUnit == unit
                                            ? FurtherPalette.background
                                            : FurtherPalette.primaryText
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .stroke(
                                                state.distanceUnit == unit
                                                    ? FurtherPalette.primaryText
                                                    : FurtherPalette.quietBorder
                                            )
                                    }
                                    .accessibilityAddTraits(
                                        state.distanceUnit == unit ? .isSelected : []
                                    )
                            }
                        }
                        .accessibilityIdentifier("settings.distance-unit")
                    }
                    .padding(.vertical, 10)
                    quietRule
                }

                sectionTitle(AppText.permissions)
                VStack(spacing: 0) {
                    quietRule
                    permissionRow(
                        title: AppText.location,
                        description: locationDescription,
                        accessibilityIdentifier: "settings.location-status"
                    ) {
                        systemSettingsLink(label: AppText.openSystemSettings)
                    }
                    quietRule
                    permissionRow(
                        title: AppText.health,
                        description: healthDescription,
                        accessibilityIdentifier: "settings.health-status"
                    ) {
                        if state.healthAuthorization == .notDetermined,
                           state.canRequestHealthAuthorization {
                            Button(AppText.allowHealthAccess, action: onRequestHealthAuthorization)
                                .font(.footnote)
                                .underline(color: FurtherPalette.quietBorder)
                                .disabled(state.isRequestingHealthAuthorization)
                                .accessibilityIdentifier("settings.request-health")
                        } else {
                            systemSettingsLink(label: AppText.openSystemSettings)
                        }
                    }
                    quietRule
                }

                Text(AppText.permissionsDegradationMessage)
                    .font(.footnote)
                    .foregroundStyle(FurtherPalette.secondaryText)
                    .padding(.top, 18)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .accessibilityIdentifier("settings.view")
        .navigationBarBackButtonHidden()
        .furtherPage()
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(FurtherPalette.secondaryText)
            .padding(.top, 27)
            .padding(.bottom, 8)
    }

    private func permissionRow<Action: View>(
        title: String,
        description: String,
        accessibilityIdentifier: String,
        @ViewBuilder action: () -> Action
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(FurtherPalette.secondaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(accessibilityIdentifier)
            Spacer(minLength: 8)
            action()
        }
        .frame(minHeight: 60)
        .padding(.vertical, 6)
    }

    private func systemSettingsLink(label: String) -> some View {
        Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
            Text(label)
                .font(.footnote)
                .underline(color: FurtherPalette.quietBorder)
        }
        .accessibilityIdentifier("settings.system-settings")
    }

    private var quietRule: some View {
        Rectangle().fill(FurtherPalette.quietBorder).frame(height: 1)
    }

    private var locationDescription: String {
        switch state.locationAuthorization {
        case .notDetermined: AppText.permissionNotRequested
        case .authorized: AppText.permissionAllowed
        case .denied: AppText.permissionDenied
        case .unavailable: AppText.permissionUnavailable
        }
    }

    private var healthDescription: String {
        switch state.healthAuthorization {
        case .notDetermined: AppText.permissionNotRequested
        case .authorized: AppText.permissionAllowed
        case .denied: AppText.permissionDenied
        case .unavailable: AppText.permissionUnavailable
        }
    }
}
