import Foundation
import XCTest
@testable import Further

final class AppBootstrapTests: XCTestCase {
    func testEmptyStoreRoutesToArtworkSelection() async throws {
        let now = Date(timeIntervalSince1970: 1_800_300_000)
        let timeSource = ControlledTimeSource(now: now)
        let bootstrap = AppBootstrap(
            containerSource: .testing,
            timeSource: timeSource
        )

        let result = await bootstrap.start()

        guard case let .ready(app) = result else {
            return XCTFail("Expected bootstrap to succeed")
        }
        XCTAssertEqual(app.route, .artworkSelection)
        XCTAssertNil(app.notice)
    }

    func testOpenFailureReturnsBlockingStateWithoutFallbackStore() async {
        let source = ModelContainerSource {
            throw AppBootstrapFailure.dataUnavailable
        }
        let bootstrap = AppBootstrap(
            containerSource: source,
            timeSource: SystemTimeSource()
        )

        let result = await bootstrap.start()

        guard case let .blocked(error) = result else {
            return XCTFail("A replacement database must not be created")
        }
        XCTAssertEqual(error, .dataUnavailable)
    }
}
