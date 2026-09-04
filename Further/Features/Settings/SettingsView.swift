import SwiftUI
import UIKit

struct SettingsView: View {
    let state: SettingsViewState
    let onSelectDistanceUnit: (DistanceUnit) -> Void
    let onRequestHealthAuthorization: () -> Void
    let onBack: () -> Void

    var body: some View {
        Form {
            Section(AppText.distanceUnit) {
                Picker(AppText.distanceUnit, selection: distanceBinding) {
                    ForEach(DistanceUnit.allCases, id: \.self) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.distance-unit")
            }

            Section(AppText.permissions) {
                permissionRow(
                    title: AppText.location,
                    state: locationDescription,
                    accessibilityIdentifier: "settings.location-status"
                )
                permissionRow(
                    title: AppText.health,
                    state: healthDescription,
                    accessibilityIdentifier: "settings.health-status"
                )

                if state.healthAuthorization == .notDetermined,
                   state.canRequestHealthAuthorization {
                    Button(AppText.allowHealthAccess, action: onRequestHealthAuthorization)
                        .disabled(state.isRequestingHealthAuthorization)
                        .accessibilityIdentifier("settings.request-health")
                }

                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Label(AppText.openSystemSettings, systemImage: "gear")
                }
                .accessibilityIdentifier("settings.system-settings")
            }
        }
        .navigationTitle(AppText.settings)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppText.back, action: onBack)
            }
        }
        .navigationBarBackButtonHidden()
        .accessibilityIdentifier("settings.view")
    }

    private var distanceBinding: Binding<DistanceUnit> {
        Binding(
            get: { state.distanceUnit },
            set: { unit in onSelectDistanceUnit(unit) }
        )
    }

    private func permissionRow(
        title: String,
        state: String,
        accessibilityIdentifier: String
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(state).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
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
