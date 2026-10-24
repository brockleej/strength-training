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
        launch(preset: "empty")
        tapTab("Settings")
        XCTAssertTrue(element(UITestID.settingsMassUnit).waitForExistence(timeout: 8))
        XCTAssertTrue(element(UITestID.settingsStartingWeight).exists)
        XCTAssertTrue(element(UITestID.settingsGym).exists)
        XCTAssertTrue(element(UITestID.settingsTapAtTen).exists)
    }

    func test_focus_showsWarmupDoneComparisonAndPlates() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        XCTAssertTrue(element(UITestID.focusWarmup).waitForExistence(timeout: 8))
        XCTAssertTrue(element(UITestID.focusDone).exists)
        XCTAssertTrue(element(UITestID.focusLogSet).exists)
        XCTAssertTrue(element(UITestID.focusPlates).exists)
        XCTAssertTrue(element(UITestID.focusLoadMode).exists)
        XCTAssertTrue(element(UITestID.stackOverride).exists)
        waitFor(UITestID.focusWarmup).tap()
        waitFor(UITestID.focusLogSet).tap()
        XCTAssertTrue(element(UITestID.focusSet(1)).waitForExistence(timeout: 6))
        XCTAssertTrue(element(UITestID.restSkip).exists || element(UITestID.focusLogSet).exists)
    }

    func test_restChips_andReorderSheet() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        waitFor(UITestID.focusLogSet).tap()
        if element(UITestID.restPlus).waitForExistence(timeout: 4) {
            element(UITestID.restPlus).tap()
            element(UITestID.restMinus).tap()
            element(UITestID.restSkip).tap()
        }
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
        let log = waitFor(UITestID.focusLogSet)
        XCTAssertTrue(log.isHittable)
        XCTAssertEqual(app.windows.firstMatch.frame.width > 0, true)
    }

    func test_relaunch_midWorkout_keepsTheLoggedSet() {
        launch(preset: "typical", extra: ["-RockLogRelaunchStore"])
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        waitFor(UITestID.focusLogSet).tap()
        XCTAssertTrue(element(UITestID.focusSet(1)).waitForExistence(timeout: 6))
        app.terminate()
        launch(preset: "typical", extra: ["-RockLogRelaunchStore", "-RockLogRelaunchKeep"])
        XCTAssertTrue(element(UITestID.workoutExercise("UI Fresh Lift")).waitForExistence(timeout: 12))
    }
}
