import XCTest

@MainActor
final class FurtherUITests: XCTestCase {
    func testLaunchPage() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        let productName = app.staticTexts["launch.product-name"]
        let tagline = app.staticTexts["launch.tagline"]

        XCTAssertTrue(productName.waitForExistence(timeout: 5))
        XCTAssertEqual(productName.label, "Further")
        XCTAssertTrue(tagline.exists)
        XCTAssertEqual(tagline.label, "still going.")
    }
}
