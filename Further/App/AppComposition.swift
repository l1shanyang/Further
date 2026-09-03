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

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppComposition {
        arguments.contains(uiTestingLaunchArgument) ? .testing() : .production()
    }

    static func production() -> AppComposition {
        AppComposition(
            dataSource: .production,
            containerSource: .production,
            timeSource: SystemTimeSource()
        )
    }

    static func testing() -> AppComposition {
        AppComposition(
            dataSource: .testing,
            containerSource: .testing,
            timeSource: SystemTimeSource()
        )
    }

    var bootstrap: AppBootstrap {
        AppBootstrap(containerSource: containerSource, timeSource: timeSource)
    }

    var rootView: some View {
        AppRootView(model: AppRootModel(
            bootstrap: bootstrap,
            timeSource: timeSource,
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
