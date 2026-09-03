import XCTest
@testable import Further

@MainActor
final class FurtherTests: XCTestCase {
    func testLaunchCopyComesFromStringCatalog() {
        XCTAssertEqual(AppText.productName, "Further")
        XCTAssertEqual(AppText.launchTagline, "still going.")
    }

    func testProductionCompositionUsesProductionData() {
        XCTAssertEqual(AppComposition.production().dataSource, .production)
    }

    func testUITestingLaunchArgumentUsesTestData() {
        let composition = AppComposition.current(arguments: [
            "Further",
            AppComposition.uiTestingLaunchArgument,
        ])

        XCTAssertEqual(composition.dataSource, .testing)
    }
}
