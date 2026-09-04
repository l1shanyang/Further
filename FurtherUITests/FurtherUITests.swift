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

    func testIndoorRunCanPauseAndCancelEnding() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        XCTAssertTrue(app.scrollViews["cycle.selection"].waitForExistence(timeout: 5))
        app.buttons["cycle.confirm"].tap()
        XCTAssertTrue(app.buttons["artwork.prepare-run"].waitForExistence(timeout: 5))
        app.buttons["artwork.prepare-run"].tap()
        app.buttons["run.choose-indoor"].tap()
        app.buttons["run.start"].tap()

        XCTAssertTrue(app.buttons["run.pause"].waitForExistence(timeout: 6))
        app.buttons["run.pause"].tap()
        XCTAssertTrue(app.buttons["run.resume"].waitForExistence(timeout: 2))
        let pausedTime = app.staticTexts["run.active-time"].label

        let wait = XCTestExpectation(description: "Paused time remains still")
        _ = XCTWaiter.wait(for: [wait], timeout: 1.5)
        XCTAssertEqual(app.staticTexts["run.active-time"].label, pausedTime)

        app.buttons["run.end"].tap()
        XCTAssertTrue(app.buttons["run.keep-running"].waitForExistence(timeout: 2))
        app.buttons["run.keep-running"].tap()
        XCTAssertTrue(app.buttons["run.resume"].waitForExistence(timeout: 2))
    }

    func testIndoorRunReflectionEntersArtwork() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        XCTAssertTrue(app.scrollViews["cycle.selection"].waitForExistence(timeout: 5))
        app.buttons["cycle.confirm"].tap()
        XCTAssertTrue(app.buttons["artwork.prepare-run"].waitForExistence(timeout: 5))
        app.buttons["artwork.prepare-run"].tap()
        app.buttons["run.choose-indoor"].tap()
        app.buttons["run.start"].tap()
        XCTAssertTrue(app.buttons["run.end"].waitForExistence(timeout: 6))
        app.buttons["run.end"].tap()
        app.buttons["run.confirm-end"].tap()

        XCTAssertTrue(app.scrollViews["reflection.expression"].waitForExistence(timeout: 3))
        app.buttons["reflection.color.2"].tap()
        app.buttons["reflection.finish"].tap()
        XCTAssertTrue(app.buttons["reflection.skip-distance"].waitForExistence(timeout: 3))
        app.buttons["reflection.skip-distance"].tap()

        XCTAssertTrue(app.buttons["reflection.view-artwork"].waitForExistence(timeout: 3))
        app.buttons["reflection.view-artwork"].tap()
        XCTAssertTrue(app.scrollViews["artwork.current"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Your current artwork"].exists)
    }

    func testOutdoorRunWithoutLocationStillCompletes() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        XCTAssertTrue(app.scrollViews["cycle.selection"].waitForExistence(timeout: 5))
        app.buttons["cycle.confirm"].tap()
        XCTAssertTrue(app.buttons["artwork.prepare-run"].waitForExistence(timeout: 5))
        app.buttons["artwork.prepare-run"].tap()
        app.buttons["run.choose-outdoor"].tap()

        XCTAssertTrue(app.staticTexts["run.location-unavailable"].waitForExistence(timeout: 2))
        app.buttons["run.start"].tap()
        XCTAssertTrue(app.buttons["run.end"].waitForExistence(timeout: 6))
        XCTAssertEqual(app.staticTexts["run.distance-value"].label, "Not recorded")
        app.buttons["run.end"].tap()
        app.buttons["run.confirm-end"].tap()
        XCTAssertTrue(app.scrollViews["reflection.expression"].waitForExistence(timeout: 3))
        app.buttons["reflection.keep-silence"].tap()

        XCTAssertTrue(app.buttons["reflection.view-artwork"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["reflection.skip-distance"].exists)
    }
}
