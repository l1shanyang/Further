import Foundation
import SwiftData
import XCTest
@testable import Further

@MainActor
final class AppRootModelTests: XCTestCase {
    func testFirstLaunchCreatesBlankTimeArtworkAndRestartRestoresIt() async throws {
        let container = try FurtherModelContainer.inMemory()
        let source = ModelContainerSource { container }
        let now = Date(timeIntervalSince1970: 1_810_000_000)
        let timeSource = ControlledTimeSource(now: now)
        let firstModel = AppRootModel(
            bootstrap: AppBootstrap(containerSource: source, timeSource: timeSource),
            timeSource: timeSource
        )

        await firstModel.start()
        XCTAssertEqual(firstModel.state, .cycleSelection(isCreating: false))

        await firstModel.createArtwork(cycle: .time(.oneMonth))
        guard case let .currentArtwork(firstState) = firstModel.state else {
            return XCTFail("Expected a current artwork")
        }
        XCTAssertEqual(firstState.artwork.state, .blank)
        XCTAssertTrue(firstState.presentation.marks.isEmpty)

        let restartedModel = AppRootModel(
            bootstrap: AppBootstrap(containerSource: source, timeSource: timeSource),
            timeSource: timeSource
        )
        await restartedModel.start()

        guard case let .currentArtwork(restoredState) = restartedModel.state else {
            return XCTFail("Expected restart to restore the current artwork")
        }
        XCTAssertEqual(restoredState.artwork, firstState.artwork)
        XCTAssertEqual(restoredState.artwork.state, .blank)
        XCTAssertEqual(restoredState.presentation, firstState.presentation)
    }
}
