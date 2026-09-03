import XCTest

@MainActor
final class FurtherUITests: XCTestCase {
    func testFirstLaunchCreatesBlankArtwork() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        let selection = app.scrollViews["cycle.selection"]
        XCTAssertTrue(selection.waitForExistence(timeout: 5))

        app.buttons["cycle.confirm"].tap()

        let currentArtwork = app.scrollViews["artwork.current"]
        XCTAssertTrue(currentArtwork.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["A new artwork"].exists)
        XCTAssertTrue(app.staticTexts["Your first run will leave the first mark."].exists)
    }
}
