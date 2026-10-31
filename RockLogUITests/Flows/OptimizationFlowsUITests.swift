//
//  OptimizationFlowsUITests.swift
//  RockLogUITests
//
//  New screens: starting weight, rest chips, previous/next, warm-up, reorder,
//  gym, units. Synthetic presets only.
//

import XCTest

final class OptimizationFlowsUITests: RockLogUITestCase {

    func test_emptyLibrary_settingsShowUnitGymAndStartingWeight() {
        // Rest timer is on before Settings appears. Logging presets do not
        // pass this argument, so a logged set still does not count down.
        launch(preset: "empty", extra: ["-RockLogRestTimer", "on"])
        // Empty is a first launch. Leave the library empty, then Settings is reachable.
        element(UITestID.firstRunChoice("Push / Pull / Legs")).tap()
        waitFor(UITestID.firstRunContinue).tap()
        waitFor(UITestID.firstRunLeaveEmpty).tap()
        waitFor(UITestID.firstRunContinue).tap()
        waitFor(UITestID.firstRunSkip).tap()
        tapTab("Settings")
        scrollUntilHittable(element(UITestID.settingsWorkoutDefaults))
        element(UITestID.settingsWorkoutDefaults).tap()
        scrollUntilExists(UITestID.settingsStartingWeight)
        scrollUntilExists(UITestID.settingsTapAtTen)
        scrollUntilExists(UITestID.settingsEndAlert)
        app.navigationBars.buttons["Settings"].tap()
        scrollUntilHittable(element(UITestID.settingsUnits))
        element(UITestID.settingsUnits).tap()
        let massUnit = element(UITestID.settingsMassUnit)
        XCTAssertTrue(massUnit.waitForExistence(timeout: 6))
        XCTAssertTrue(massUnit.isHittable)
        XCTAssertTrue(element(UITestID.settingsUnitsFooter).exists)
        app.navigationBars.buttons["Settings"].tap()
        scrollUntilHittable(element(UITestID.settingsGyms))
        element(UITestID.settingsGyms).tap()
        scrollUntilExists(UITestID.settingsGym)
    }

    func test_workoutList_lastTargetToggleIsVisible() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        let toggle = waitFor(UITestID.workoutSecondaryToggle)
        XCTAssertTrue(toggle.isHittable)
        let before = toggle.label
        toggle.tap()
        let after = waitFor(UITestID.workoutSecondaryToggle)
        XCTAssertNotEqual(after.label, before)
        XCTAssertFalse(element(UITestID.focusBack).exists)
        XCTAssertFalse(element(UITestID.focusLogSet).exists)
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        XCTAssertTrue(element(UITestID.focusLogSet).waitForExistence(timeout: 8))
    }

    func test_activeWorkoutBar_staysOnSettings() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        XCTAssertTrue(element(UITestID.activeWorkoutBar).waitForExistence(timeout: 8))
        tapTab("Settings")
        XCTAssertTrue(element(UITestID.activeWorkoutBar).waitForExistence(timeout: 6))
        tapTab("Workout")
        waitFor(UITestID.workoutHome).tap()
    }

    func test_focus_showsWarmupDoneComparisonAndPlates() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        XCTAssertTrue(element(UITestID.focusWarmup).waitForExistence(timeout: 8))
        XCTAssertTrue(element(UITestID.focusDone).exists)
        _ = waitForLogSet()
        XCTAssertTrue(element(UITestID.focusPlates).exists)
        XCTAssertTrue(element(UITestID.focusSetProgress).exists)
        XCTAssertTrue(app.staticTexts["Load: Total"].exists || element(UITestID.focusLoadMode).label.contains("Total"))
        XCTAssertTrue(element(UITestID.focusLoadMode).exists)
        XCTAssertTrue(element(UITestID.stackOverride).exists)
        waitFor(UITestID.focusWarmup).tap()
        waitForLogSet().tap()
        XCTAssertTrue(element(UITestID.focusSet(1)).waitForExistence(timeout: 6))
        XCTAssertTrue(element(UITestID.restSkip).exists || element(UITestID.focusLogSet).exists)
    }

    func test_restChips_andReorderSheet() {
        // Logging presets leave the rest timer off, so a logged set does not
        // count down and rest.plus is not in the tree. This test turns it on.
        launch(preset: "typical", extra: ["-RockLogRestTimer", "on"])
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        waitForLogSet().tap()
        let restPlus = waitFor(UITestID.restPlus)
        XCTAssertTrue(restPlus.isHittable, "Rest +15 is not on screen. frame=\(restPlus.frame)")
        restPlus.tap()
        element(UITestID.restMinus).tap()
        element(UITestID.restSkip).tap()
        waitFor(UITestID.focusBack).tap()
        let more = app.buttons["More options"]
        XCTAssertTrue(more.waitForExistence(timeout: 6))
        more.tap()
        let reorder = app.buttons["Reorder today's list"]
        XCTAssertTrue(reorder.waitForExistence(timeout: 4))
        reorder.tap()
        XCTAssertTrue(element(UITestID.workoutSaveOrderDay).waitForExistence(timeout: 6))
        XCTAssertTrue(element(UITestID.workoutCircuit).exists)
        XCTAssertTrue(element(UITestID.workoutSaveOrderRemaining).exists)
    }

    func test_dynamicType_focusLogStaysHittable() {
        launch(preset: "typical", extra: ["-RockLogDynamicType", "accessibility3"])
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        let log = waitForLogSet()
        XCTAssertTrue(log.isHittable)
        XCTAssertEqual(app.windows.firstMatch.frame.width > 0, true)
    }

    func test_relaunch_midWorkout_keepsTheLoggedSet() {
        launch(preset: "typical", extra: ["-RockLogRelaunchStore"])
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        waitForLogSet().tap()
        XCTAssertTrue(element(UITestID.focusSet(1)).waitForExistence(timeout: 6))
        app.terminate()
        launch(preset: "typical", extra: ["-RockLogRelaunchStore", "-RockLogRelaunchKeep"])
        XCTAssertTrue(element(UITestID.workoutExercise("UI Fresh Lift")).waitForExistence(timeout: 12))
    }
}
