import XCTest

final class FitnessAppUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        return app
    }

    @MainActor
    func testLaunchDoesNotRequireHealthPermission() {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Profile"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.alerts.count == 0)
    }

    @MainActor
    func testManualMealRejectsZeroCaloriesAndCanBeCancelled() {
        let app = launch()
        app.buttons["dashboard-calories"].tap()
        app.buttons["add-meal"].tap()
        XCTAssertTrue(app.textFields["meal-calories"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars.buttons["Save"].isEnabled)
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertFalse(app.textFields["meal-calories"].exists)
    }

    @MainActor
    func testProfileChangesSaveExplicitly() {
        let app = launch()
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Save"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Profile saved."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testProfileUnitLabelsFollowUnsavedSelection() {
        let app = launch()
        app.tabBars.buttons["Profile"].tap()
        let imperial = app.segmentedControls.buttons["Imperial"]
        XCTAssertTrue(imperial.waitForExistence(timeout: 5))
        imperial.tap()
        XCTAssertEqual(app.staticTexts["profile-height-unit"].label, "in")
        XCTAssertEqual(app.staticTexts["profile-weight-unit"].label, "lbs")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Profile saved."].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["profile-weight-unit"].label, "lbs")
    }

    @MainActor
    func testWorkoutCanBeLoggedAndDeletionRequiresConfirmation() {
        let app = launch()
        app.tabBars.buttons["Workouts"].tap()
        app.buttons["add-workout"].tap()
        XCTAssertTrue(app.buttons["save-workout"].waitForExistence(timeout: 5))
        app.buttons["save-workout"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Edit"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Edit"].tap()
        app.buttons["Delete Cardio workout"].tap()
        XCTAssertTrue(app.buttons["Delete Workout"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Delete Cardio workout"].exists)
        app.buttons["Delete Cardio workout"].tap()
        app.buttons["Delete Workout"].tap()
        XCTAssertTrue(app.staticTexts["Your next chapter starts here"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testChartTimeRangesShowCalendarDayCoverage() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--chart-fixtures"]
        app.launch()
        app.buttons["dashboard-calories"].tap()
        let range = app.segmentedControls["chart-period"]
        XCTAssertTrue(range.waitForExistence(timeout: 5))
        range.buttons["7 days"].tap()
        XCTAssertTrue(app.staticTexts["7 / 7"].waitForExistence(timeout: 5))
        range.buttons["90 days"].tap()
        XCTAssertTrue(app.staticTexts["90 / 90"].waitForExistence(timeout: 5))
    }
}
