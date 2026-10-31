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
        XCTAssertTrue(element(UITestID.workoutSaveToday).waitForExistence(timeout: 6))
        XCTAssertTrue(element(UITestID.workoutCircuit).exists)
        XCTAssertTrue(element(UITestID.workoutSaveOrderRemaining).exists)
        XCTAssertFalse(app.buttons["Add"].exists, "No stray Add links on the reorder sheet")
        element(UITestID.workoutSaveToday).tap()
        XCTAssertFalse(element(UITestID.workoutSaveToday).waitForExistence(timeout: 2))
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

    /// Items 11–12: make Circuit A in Reorder Today, then log inside it. Same Focus screen and
    /// Log set; inside a round the app goes straight to the next lift with no rest timer.
    func test_circuit_madeInReorder_logsWithoutRestInsideARound() {
        launch(preset: "typical", extra: ["-RockLogRestTimer", "on"])
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        XCTAssertTrue(element(UITestID.workoutExercise("UI Fresh Lift")).waitForExistence(timeout: 8))
        let more = app.buttons["More options"]
        XCTAssertTrue(more.waitForExistence(timeout: 6))
        more.tap()
        let reorder = app.buttons["Reorder today's list"]
        XCTAssertTrue(reorder.waitForExistence(timeout: 4))
        reorder.tap()
        waitFor(UITestID.workoutCircuit).tap()
        waitFor(UITestID.circuitPick("UI Bench Press")).tap()
        waitFor(UITestID.circuitPick("UI Fresh Lift")).tap()
        XCTAssertTrue(element(UITestID.circuitRest).waitForExistence(timeout: 4))
        waitFor(UITestID.circuitCreate).tap()
        XCTAssertTrue(element(UITestID.reorderCircuit("A")).waitForExistence(timeout: 6))
        waitFor(UITestID.workoutSaveToday).tap()
        waitFor(UITestID.workoutExercise("UI Bench Press")).tap()
        XCTAssertTrue(element(UITestID.focusCircuitRound).waitForExistence(timeout: 8))
        XCTAssertTrue(element(UITestID.focusCircuitLift("UI Fresh Lift")).exists)
        waitForLogSet().tap()
        // Inside the round: no rest, and Focus now shows the other lift's strip as current.
        XCTAssertFalse(element(UITestID.restSkip).waitForExistence(timeout: 2), "No rest between lifts inside a round")
        XCTAssertTrue(element(UITestID.focusCircuitRound).waitForExistence(timeout: 6))
        XCTAssertTrue(element(UITestID.focusLogSet).exists)
    }

    // MARK: - 1.2 circuit gaps (c) round break, (d) End circuit early, (e) Start Circuit A

    /// Circuit A = UI Bench Press → UI Fresh Lift, saved for today; returns on the list.
    private func makeCircuitA(extra: [String] = []) {
        launch(preset: "typical", extra: ["-RockLogRestTimer", "on"] + extra)
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        XCTAssertTrue(element(UITestID.workoutExercise("UI Fresh Lift")).waitForExistence(timeout: 8))
        let more = app.buttons["More options"]
        XCTAssertTrue(more.waitForExistence(timeout: 6))
        more.tap()
        let reorder = app.buttons["Reorder today's list"]
        XCTAssertTrue(reorder.waitForExistence(timeout: 4))
        reorder.tap()
        waitFor(UITestID.workoutCircuit).tap()
        waitFor(UITestID.circuitPick("UI Bench Press")).tap()
        waitFor(UITestID.circuitPick("UI Fresh Lift")).tap()
        waitFor(UITestID.circuitCreate).tap()
        XCTAssertTrue(element(UITestID.reorderCircuit("A")).waitForExistence(timeout: 6))
        waitFor(UITestID.workoutSaveToday).tap()
    }

    /// From the list: Start Circuit A, log one round, land on the round-complete rest.
    private func startAndFinishRoundOne() {
        let start = waitFor(UITestID.workoutCircuitStart("A"))
        XCTAssertEqual(start.label, "Start Circuit A")
        start.tap()
        XCTAssertTrue(element(UITestID.focusCircuitRound).waitForExistence(timeout: 8))
        waitForLogSet().tap()
        XCTAssertFalse(element(UITestID.focusCircuitBreak).waitForExistence(timeout: 1), "No break inside a round")
        waitForLogSet().tap()
        XCTAssertTrue(element(UITestID.focusCircuitBreak).waitForExistence(timeout: 6), "Round-complete rest after the round")
    }

    /// Unity rule: during the break it is still the normal Focus screen with Log set and the rest card.
    private func assertBreakLooksLikeAnyLift() {
        XCTAssertTrue(element(UITestID.focusCircuitUpNext).exists)
        XCTAssertTrue(element(UITestID.restSkip).exists, "Same rest timer (Skip) as a standalone lift")
        XCTAssertTrue(element(UITestID.focusLogSet).exists, "Same Log set button")
        XCTAssertTrue(element(UITestID.focusCircuitEndEarly).exists)
    }

    func test_circuitStart_roundBreak_thenSkipLoopsToRoundTwo() {
        makeCircuitA()
        startAndFinishRoundOne()
        assertBreakLooksLikeAnyLift()
        element(UITestID.restSkip).tap()
        XCTAssertFalse(element(UITestID.focusCircuitBreak).waitForExistence(timeout: 2))
        let pill = waitFor(UITestID.focusCircuitRound)
        XCTAssertTrue(pill.label.contains("Round 2"), "After the break it loops to round 2: \(pill.label)")
    }

    func test_endCircuitEarly_returnsToTheList_andMarksTheCircuitDone() {
        makeCircuitA()
        startAndFinishRoundOne()
        waitFor(UITestID.focusCircuitEndEarly).tap()
        let start = waitFor(UITestID.workoutCircuitStart("A"))
        XCTAssertEqual(start.label, "Circuit A done")
        XCTAssertFalse(element(UITestID.restSkip).exists, "Ending early stops the rest")
    }

    func test_endCircuitEarly_fromTheMenu_midRound() {
        makeCircuitA()
        waitFor(UITestID.workoutCircuitStart("A")).tap()
        waitForLogSet().tap()
        let more = app.buttons["More options"]
        XCTAssertTrue(more.waitForExistence(timeout: 6))
        more.tap()
        waitFor(UITestID.focusCircuitEndEarlyMenu).tap()
        XCTAssertEqual(waitFor(UITestID.workoutCircuitStart("A")).label, "Circuit A done")
    }

    func test_roundBreak_survivesBackgrounding() {
        makeCircuitA()
        startAndFinishRoundOne()
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        XCTAssertTrue(element(UITestID.focusCircuitBreak).waitForExistence(timeout: 8))
        assertBreakLooksLikeAnyLift()
    }

    func test_roundBreak_resumesAfterRelaunch() {
        makeCircuitA(extra: ["-RockLogRelaunchStore"])
        startAndFinishRoundOne()
        app.terminate()
        launch(preset: "typical", extra: ["-RockLogRestTimer", "on", "-RockLogRelaunchStore", "-RockLogRelaunchKeep"])
        let start = waitFor(UITestID.workoutCircuitStart("A"))
        XCTAssertTrue(start.label.hasPrefix("Continue Circuit A · Round 2"), start.label)
        start.tap()
        XCTAssertTrue(element(UITestID.focusCircuitBreak).waitForExistence(timeout: 8), "Break comes back from the last set's time")
        assertBreakLooksLikeAnyLift()
    }

    func test_roundBreak_lightAppearance_andLargeText() {
        makeCircuitA(extra: ["-appearanceChoice", "light", "-RockLogDynamicType", "accessibility3"])
        startAndFinishRoundOne()
        assertBreakLooksLikeAnyLift()
        XCTAssertTrue(waitForLogSet().isHittable)
        XCTAssertTrue(element(UITestID.focusCircuitEndEarly).isHittable)
    }

    func test_roundBreak_darkAppearance_andLargeText() {
        makeCircuitA(extra: ["-appearanceChoice", "dark", "-RockLogDynamicType", "accessibility1"])
        startAndFinishRoundOne()
        assertBreakLooksLikeAnyLift()
        XCTAssertTrue(waitForLogSet().isHittable)
        XCTAssertTrue(element(UITestID.focusCircuitEndEarly).isHittable)
    }
}

