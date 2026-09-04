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

    func testFinalizedRunCanBeOpenedFromLookback() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        XCTAssertTrue(app.scrollViews["cycle.selection"].waitForExistence(timeout: 5))
        app.buttons["cycle.confirm"].tap()
        app.buttons["artwork.prepare-run"].tap()
        app.buttons["run.choose-indoor"].tap()
        app.buttons["run.start"].tap()
        XCTAssertTrue(app.buttons["run.end"].waitForExistence(timeout: 6))
        app.buttons["run.end"].tap()
        app.buttons["run.confirm-end"].tap()
        XCTAssertTrue(app.scrollViews["reflection.expression"].waitForExistence(timeout: 3))
        app.buttons["reflection.keep-silence"].tap()
        app.buttons["reflection.skip-distance"].tap()
        app.buttons["reflection.view-artwork"].tap()

        XCTAssertTrue(app.buttons["artwork.lookback"].waitForExistence(timeout: 3))
        app.buttons["artwork.lookback"].tap()
        XCTAssertTrue(app.collectionViews["lookback.list"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No note"].exists)
        XCTAssertTrue(app.staticTexts["Not recorded"].exists)
        app.buttons["lookback.record"].tap()
        XCTAssertTrue(app.scrollViews["record.detail"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["record.route-missing"].exists)
        XCTAssertFalse(app.buttons["Delete"].exists)
        XCTAssertFalse(app.buttons["Edit"].exists)
    }

    func testCompletedArtworkMovesIntoCollectionWhenNextArtworkStarts() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        XCTAssertTrue(app.scrollViews["cycle.selection"].waitForExistence(timeout: 5))
        app.buttons["cycle.option.tenKilometers"].tap()
        app.buttons["cycle.confirm"].tap()
        app.buttons["artwork.prepare-run"].tap()
        app.buttons["run.choose-indoor"].tap()
        app.buttons["run.start"].tap()
        XCTAssertTrue(app.buttons["run.end"].waitForExistence(timeout: 6))
        app.buttons["run.end"].tap()
        app.buttons["run.confirm-end"].tap()
        XCTAssertTrue(app.scrollViews["reflection.expression"].waitForExistence(timeout: 3))
        app.buttons["reflection.keep-silence"].tap()
        let distance = app.textFields["reflection.distance"]
        XCTAssertTrue(distance.waitForExistence(timeout: 3))
        distance.tap()
        distance.typeText("10")
        app.buttons["reflection.save-distance"].tap()
        app.buttons["reflection.view-artwork"].tap()

        XCTAssertTrue(app.buttons["artwork.start-next"].waitForExistence(timeout: 3))
        app.buttons["artwork.start-next"].tap()
        XCTAssertTrue(app.scrollViews["cycle.selection"].waitForExistence(timeout: 3))
        app.buttons["cycle.confirm"].tap()
        XCTAssertTrue(app.staticTexts["A new artwork"].waitForExistence(timeout: 3))

        app.buttons["artwork.collection"].tap()
        XCTAssertTrue(app.collectionViews["collection.list"].waitForExistence(timeout: 3))
        app.buttons["collection.artwork"].tap()
        XCTAssertTrue(app.scrollViews["collection.detail"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Delete"].exists)
        XCTAssertFalse(app.buttons["Share"].exists)
    }

    func testSettingsPersistDistanceUnitAndShowPermissionStates() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        XCTAssertTrue(app.scrollViews["cycle.selection"].waitForExistence(timeout: 5))
        app.buttons["cycle.confirm"].tap()
        XCTAssertTrue(app.buttons["artwork.settings"].waitForExistence(timeout: 3))
        app.buttons["artwork.settings"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["settings.view"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.descendants(matching: .any)["settings.location-status"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.health-status"].exists)
        app.buttons["Miles"].tap()
        XCTAssertTrue(app.buttons["Miles"].isSelected)

        app.buttons["Back"].tap()
        XCTAssertTrue(app.scrollViews["artwork.current"].waitForExistence(timeout: 3))
        app.buttons["artwork.settings"].tap()
        XCTAssertTrue(app.buttons["Miles"].isSelected)
    }
}
