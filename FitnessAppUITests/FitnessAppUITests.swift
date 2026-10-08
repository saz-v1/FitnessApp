import XCTest

final class FitnessAppUITests: XCTestCase {
    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait
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

    @MainActor
    func testSettingsReminderDaysPersistWithoutEnablingPermission() {
        let app = launch()
        let dashboard = XCTAttachment(screenshot: app.screenshot())
        dashboard.name = "Centred dashboard"; dashboard.lifetime = .keepAlways; add(dashboard)
        func openReminders() {
            app.tabBars.buttons["Profile"].tap()
            app.buttons["profile-settings"].tap()
            app.buttons["settings-reminders"].tap()
        }
        openReminders()
        let sunday = app.buttons["reminder-meal-day-1"]
        for _ in 0..<5 {
            if sunday.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(sunday.isHittable)
        let previous = sunday.value as? String
        sunday.tap()
        let selected = sunday.value as? String
        XCTAssertNotEqual(previous, selected)
        XCTAssertFalse(app.alerts.count > 0)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Custom reminders"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.terminate()
        app.launchArguments.append("--preserve-test-preferences")
        app.launch()
        openReminders()
        let restoredSunday = app.buttons["reminder-meal-day-1"]
        for _ in 0..<5 {
            if restoredSunday.isHittable { break }
            app.swipeUp()
        }
        let persisted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", selected ?? ""),
            object: restoredSunday)
        XCTAssertEqual(XCTWaiter.wait(for: [persisted], timeout: 5), .completed)
        restoredSunday.tap()
    }

    @MainActor
    func testInvalidProfileInputDisablesSaveAndCanBeDiscarded() {
        let app = launch()
        app.tabBars.buttons["Profile"].tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Profile and settings"; screenshot.lifetime = .keepAlways; add(screenshot)
        let height = app.textFields["profile-height"]
        XCTAssertTrue(height.waitForExistence(timeout: 5))
        height.doubleTap()
        height.typeText("0")
        XCTAssertEqual(height.value as? String, "0")
        XCTAssertFalse(app.navigationBars.buttons["Save"].isEnabled)
        app.toolbars.buttons["Done"].tap()
        app.buttons["Discard"].tap()
        app.buttons["Discard Changes"].tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "170"), object: height)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed)
        let saveEnabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"),
            object: app.navigationBars.buttons["Save"])
        XCTAssertEqual(XCTWaiter.wait(for: [saveEnabled], timeout: 5), .completed)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<6 { if element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    func testSavedMealCanBeReusedWithoutReplacingOriginalEntry() {
        let app = launch()
        app.buttons["dashboard-calories"].tap(); app.buttons["add-meal"].tap()
        let calories = app.textFields["meal-calories"]
        XCTAssertTrue(calories.waitForExistence(timeout: 5))
        calories.tap(); calories.typeText("500")
        app.toolbars.buttons["Done"].tap()
        let preset = app.switches["save-meal-preset"]
        reveal(preset, app: app)
        preset.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: preset)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        reveal(app.textFields["saved-meal-name"], app: app)
        app.buttons["save-meal"].tap()
        let library = app.buttons["browse-saved-meals"]
        XCTAssertTrue(library.waitForExistence(timeout: 5)); library.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved-meal-")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.textFields["meal-calories"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["meal-calories"].value as? String, "500")
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Reusable saved meal"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["save-meal"].tap()
        app.navigationBars["Saved meals"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["1,000 kcal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2 entries"].exists)
    }

    @MainActor
    func testOfflineFoodPortionCanBeAddedToMeal() {
        let app = launch()
        app.buttons["dashboard-calories"].tap(); app.buttons["add-meal"].tap()
        app.buttons["choose-food"].tap()
        let sources = app.segmentedControls["food-source"]
        XCTAssertTrue(sources.waitForExistence(timeout: 5))
        sources.buttons["UK"].tap()
        let usBanana = app.buttons["food-173944"]
        let usRowHidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: usBanana)
        XCTAssertEqual(XCTWaiter.wait(for: [usRowHidden], timeout: 5), .completed)
        let ukBanana = app.buttons["food-1000140318"]
        XCTAssertTrue(ukBanana.waitForExistence(timeout: 5))
        XCTAssertTrue(ukBanana.label.contains("UK · CoFID"))
        XCTAssertFalse(usBanana.exists)
        let ukLibrary = XCTAttachment(screenshot: app.screenshot())
        ukLibrary.name = "Combined food library - UK"; ukLibrary.lifetime = .keepAlways; add(ukLibrary)
        sources.buttons["US"].tap()
        let ukRowHidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: ukBanana)
        XCTAssertEqual(XCTWaiter.wait(for: [ukRowHidden], timeout: 5), .completed)
        XCTAssertTrue(usBanana.waitForExistence(timeout: 5))
        XCTAssertFalse(ukBanana.exists)
        let search = app.searchFields["e.g. banana or rice cooked"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("bananas raw")
        let food = app.buttons["food-173944"]
        XCTAssertTrue(food.waitForExistence(timeout: 5)); food.tap()
        XCTAssertTrue(app.textFields["food-grams"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["89 kcal"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Offline food portion"; screenshot.lifetime = .keepAlways; add(screenshot)
        let addPortion = app.buttons["add-food-portion"]
        reveal(addPortion, app: app); addPortion.tap()
        XCTAssertTrue(app.buttons["save-meal"].waitForExistence(timeout: 5))
        app.buttons["save-meal"].tap()
        XCTAssertTrue(app.staticTexts["89 kcal"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testActiveWorkoutSetAndRestSaveToHistory() {
        let app = launch()
        app.tabBars.buttons["Workouts"].tap(); app.buttons["open-active-workout"].tap()
        app.buttons["start-active-session"].tap()
        app.buttons["active-choose-exercise"].tap()
        let search = app.searchFields["e.g. squat, chest or dumbbell"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("goblet\n")
        let movement = app.buttons["exercise-pick-goblet-squat"]
        XCTAssertTrue(movement.waitForExistence(timeout: 5)); reveal(movement, app: app); movement.tap()
        let rep = app.buttons["add-rep"]
        XCTAssertTrue(rep.waitForExistence(timeout: 5)); reveal(rep, app: app)
        rep.tap(); rep.tap(); rep.tap()
        let controls = XCTAttachment(screenshot: app.screenshot()); controls.name = "Live rep controls"; controls.lifetime = .keepAlways; add(controls)
        let complete = app.buttons["complete-active-set"]
        reveal(complete, app: app); complete.tap()
        XCTAssertTrue(app.staticTexts["Set 2"].waitForExistence(timeout: 5))
        let rest = app.staticTexts["rest-timer"]
        reveal(rest, app: app)
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Active workout and rest"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["finish-active-workout"].tap(); app.buttons["Finish & Save"].tap()
        let record = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "workout-record-")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5)); reveal(record, app: app); record.tap()
        XCTAssertTrue(app.staticTexts["3 reps"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTimedLapsCanBeCompletedAndSaved() {
        let app = launch()
        app.tabBars.buttons["Workouts"].tap(); app.buttons["open-active-workout"].tap()
        app.buttons["start-active-session"].tap(); app.buttons["active-choose-exercise"].tap()
        let search = app.searchFields["e.g. squat, chest or dumbbell"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("running")
        let movement = app.buttons["exercise-pick-running"]
        XCTAssertTrue(movement.waitForExistence(timeout: 5)); movement.tap()
        let timer = app.buttons["exercise-timer-toggle"]
        XCTAssertTrue(timer.waitForExistence(timeout: 5)); reveal(timer, app: app); timer.tap()
        let lap = app.buttons["record-lap"]
        reveal(lap, app: app); lap.tap()
        XCTAssertTrue(app.staticTexts["Lap 1"].waitForExistence(timeout: 5))
        let complete = app.buttons["complete-active-set"]
        reveal(complete, app: app); complete.tap()
        app.buttons["finish-active-workout"].tap(); app.buttons["Finish & Save"].tap()
        let record = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "workout-record-")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5)); reveal(record, app: app); record.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1 lap")).firstMatch.waitForExistence(timeout: 5))
    }
}
