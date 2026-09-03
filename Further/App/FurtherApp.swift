import SwiftUI

@main
@MainActor
struct FurtherApp: App {
    private let composition: AppComposition

    init() {
        composition = AppComposition.current()
    }

    var body: some Scene {
        WindowGroup {
            composition.rootView
        }
    }
}
