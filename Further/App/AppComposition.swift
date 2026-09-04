import Foundation
import SwiftUI

enum AppDataSource: Equatable {
    case production
    case testing
}

@MainActor
struct AppComposition {
    static let uiTestingLaunchArgument = "-ui-testing"

    let dataSource: AppDataSource
    let containerSource: ModelContainerSource
    let timeSource: any TimeSource
    let locationSource: any LocationSource
    let healthWriter: any HealthWriter
    let distanceUnitStore: any DistanceUnitStoring

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppComposition {
        arguments.contains(uiTestingLaunchArgument) ? .testing() : .production()
    }

    static func production() -> AppComposition {
        AppComposition(
            dataSource: .production,
            containerSource: .production,
            timeSource: SystemTimeSource(),
            locationSource: CoreLocationSource(),
            healthWriter: HealthKitWriter(),
            distanceUnitStore: UserDefaultsDistanceUnitStore()
        )
    }

    static func testing() -> AppComposition {
        AppComposition(
            dataSource: .testing,
            containerSource: .testing,
            timeSource: SystemTimeSource(),
            locationSource: UnavailableLocationSource(),
            healthWriter: UnavailableHealthWriter(),
            distanceUnitStore: InMemoryDistanceUnitStore()
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
