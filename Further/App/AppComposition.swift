import Foundation
import SwiftUI

enum AppDataSource: Equatable {
    case production
    case testing
}

@MainActor
struct AppComposition {
    static let uiTestingLaunchArgument = "-ui-testing"
    static let uiTestingLargeTextLaunchArgument = "-ui-testing-large-text"
    static let uiTestingDarkModeLaunchArgument = "-ui-testing-dark-mode"

    let dataSource: AppDataSource
    let containerSource: ModelContainerSource
    let timeSource: any TimeSource
    let locationSource: any LocationSource
    let healthWriter: any HealthWriter
    let distanceUnitStore: any DistanceUnitStoring
    let presentationOverrides: PresentationOverrides

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppComposition {
        arguments.contains(uiTestingLaunchArgument) ? .testing(arguments: arguments) : .production()
    }

    static func production() -> AppComposition {
        AppComposition(
            dataSource: .production,
            containerSource: .production,
            timeSource: SystemTimeSource(),
            locationSource: CoreLocationSource(),
            healthWriter: HealthKitWriter(),
            distanceUnitStore: UserDefaultsDistanceUnitStore(),
            presentationOverrides: PresentationOverrides()
        )
    }

    static func testing(arguments: [String] = []) -> AppComposition {
        AppComposition(
            dataSource: .testing,
            containerSource: .testing,
            timeSource: SystemTimeSource(),
            locationSource: UnavailableLocationSource(),
            healthWriter: UnavailableHealthWriter(),
            distanceUnitStore: InMemoryDistanceUnitStore(),
            presentationOverrides: PresentationOverrides(
                dynamicTypeSize: arguments.contains(uiTestingLargeTextLaunchArgument)
                    ? .accessibility5
                    : nil,
                colorScheme: arguments.contains(uiTestingDarkModeLaunchArgument) ? .dark : nil
            )
        )
    }

    var bootstrap: AppBootstrap {
        AppBootstrap(containerSource: containerSource, timeSource: timeSource)
    }

    var rootView: some View {
        AppRootView(model: AppRootModel(
            bootstrap: bootstrap,
            timeSource: timeSource,
            locationSource: locationSource,
            healthWriter: healthWriter,
            distanceUnitStore: distanceUnitStore,
            activityOrigin: activityOrigin
        ))
        .transformEnvironment(\.dynamicTypeSize) { value in
            if let override = presentationOverrides.dynamicTypeSize {
                value = override
            }
        }
        .preferredColorScheme(presentationOverrides.colorScheme)
    }

    private var activityOrigin: ActivityOrigin {
        let bundle = Bundle.main
        return ActivityOrigin(
            productIdentifier: bundle.bundleIdentifier ?? "Further",
            productVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                as? String ?? "unknown",
            deviceModel: nil,
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString
        )
    }
}

struct PresentationOverrides {
    var dynamicTypeSize: DynamicTypeSize?
    var colorScheme: ColorScheme?
}
