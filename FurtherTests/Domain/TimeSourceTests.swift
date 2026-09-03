import Foundation
import XCTest
@testable import Further

final class TimeSourceTests: XCTestCase {
    func testControlledTimeSourceAdvancesExactly() async throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let timeSource = ControlledTimeSource(now: start)

        let initialDate = await timeSource.now()
        XCTAssertEqual(initialDate, start)
        try await timeSource.advance(by: 90)
        let advancedDate = await timeSource.now()
        XCTAssertEqual(advancedDate, start.addingTimeInterval(90))
    }
}
