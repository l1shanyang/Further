import XCTest
@testable import Further

@MainActor
final class FurtherTests: XCTestCase {
    func testProductNameComesFromStringCatalog() {
        XCTAssertEqual(AppText.productName, "Further")
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

    func testQualityLaunchArgumentsOverridePresentationOnlyForUITests() {
        let composition = AppComposition.current(arguments: [
            "Further",
            AppComposition.uiTestingLaunchArgument,
            AppComposition.uiTestingLargeTextLaunchArgument,
            AppComposition.uiTestingDarkModeLaunchArgument,
        ])

        XCTAssertEqual(composition.dataSource, .testing)
        XCTAssertEqual(composition.presentationOverrides.dynamicTypeSize, .accessibility5)
        XCTAssertEqual(composition.presentationOverrides.colorScheme, .dark)
    }
}
