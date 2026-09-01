import XCTest
@testable import Further

final class FurtherTests: XCTestCase {
    func testProductName() {
        XCTAssertEqual(FurtherApp.name, "Further")
    }
}
