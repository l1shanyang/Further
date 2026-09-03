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

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppComposition {
        arguments.contains(uiTestingLaunchArgument) ? .testing() : .production()
    }

    static func production() -> AppComposition {
        AppComposition(dataSource: .production)
    }

    static func testing() -> AppComposition {
        AppComposition(dataSource: .testing)
    }

    var rootView: some View {
        ContentView()
    }
}
